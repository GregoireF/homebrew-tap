# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"
require "socket"

# Tap::GitHub against a local HTTP server: routes, redirects, 404s, and the
# rule that the token only goes to the API host.
class GitHubTest < Minitest::Test
  # A one-thread HTTP/1.1 server answering from a route table.
  class Server
    attr_reader :requests

    def initialize(routes)
      @routes = routes
      @requests = []
      @server = TCPServer.new("127.0.0.1", 0)
      @thread = Thread.new { loop { serve(@server.accept) } }
    end

    def port = @server.addr[1]

    def stop
      @thread.kill
      @server.close
    end

    def serve(client)
      request_line = client.gets.to_s
      headers = {}
      while (line = client.gets) && line != "\r\n"
        key, value = line.split(": ", 2)
        headers[key.downcase] = value.strip
      end
      path = request_line.split[1]
      @requests << { path:, headers: }
      status, extra, body = @routes.fetch(path, [404, {}, "{}"])
      head = extra.map { |k, v| "#{k}: #{v}\r\n" }.join
      client.write "HTTP/1.1 #{status} X\r\nContent-Length: #{body.bytesize}\r\n" \
                   "Connection: close\r\n#{head}\r\n#{body}"
    ensure
      client.close
    end
  end

  def setup
    @release = {
      "tag_name"     => "v1.0.0",
      "published_at" => "2026-11-12T23:15:45Z",
      "assets"       => [{ "name" => "a.tar.gz", "browser_download_url" => "/download/a.tar.gz" }],
    }
    search = "/api/search/repositories?q=user%3Ao+topic%3Agregoiref-tap"
    repo = JSON.generate("description" => "A repo", "license" => { "spdx_id" => "MIT" }, "topics" => ["t"])
    attested = JSON.generate("attestations" => [{ "bundle" => {} }])
    with_attestation = "/api/repos/o/r/attestations/sha256:aa?per_page=1"
    without_attestation = "/api/repos/o/r/attestations/sha256:bb?per_page=1"
    @server = Server.new(
      "/api/repos/o/r/releases/latest"       => [200, {}, JSON.generate(@release)],
      search                                 => [200, {}, JSON.generate("items" => [{ "full_name" => "o/x" }])],
      "/api/repos/o/r"                       => [200, {}, repo],
      "/api/repos/o/r/releases/tags/v1.0.0"  => [200, {}, JSON.generate(@release)],
      "/api/repos/o/r/releases?per_page=100" => [200, {}, JSON.generate([
        { "tag_name" => "v1.2.0-rc.1", "prerelease" => true, "draft" => false },
        { "tag_name" => "v1.1.0", "prerelease" => false, "draft" => false },
        { "tag_name" => "v1.0.5", "prerelease" => false, "draft" => true },
        { "tag_name" => "v1.0.0", "prerelease" => false, "draft" => false },
      ])],
      with_attestation                       => [200, {}, attested],
      without_attestation                    => [200, {}, JSON.generate("attestations" => [])],
      "/download/a.tar.gz"                   => [302, { "Location" => "/storage/a.tar.gz" }, ""],
      "/storage/a.tar.gz"                    => [200, {}, "archive bytes"],
      "/loop"                                => [302, { "Location" => "/loop" }, ""],
      "/boom"                                => [500, {}, "nope"],
    )
    @base = "http://127.0.0.1:#{@server.port}"
    @github = Tap::GitHub.new(token: "secret", api: "#{@base}/api")
  end

  def teardown = @server.stop

  def test_latest_release
    assert_equal({ tag: "v1.0.0", published: "2026-11-12T23:15:45Z", assets: { "a.tar.gz" => "/download/a.tar.gz" } },
                 @github.latest_release("o/r"))
    api_call = @server.requests.first
    assert_equal "Bearer secret", api_call[:headers]["authorization"]
    assert_equal "application/vnd.github+json", api_call[:headers]["accept"]
  end

  def test_missing_release_is_nil
    assert_nil @github.latest_release("o/none")
  end

  def test_release_by_tag_and_stable_tags
    assert_equal "v1.0.0", @github.release("o/r", "v1.0.0")[:tag]
    assert_nil @github.release("o/r", "v9.9.9")
    assert_equal %w[v1.1.0 v1.0.0], @github.stable_tags("o/r")
    assert_empty @github.stable_tags("o/none")
  end

  def test_repository_and_attestations
    assert_equal({ description: "A repo", license: "MIT", topics: ["t"] }, @github.repository("o/r"))
    assert_raises(Tap::Error) { @github.repository("o/none") }
    assert @github.attested?("o/r", "aa")
    refute @github.attested?("o/r", "bb")
    refute @github.attested?("o/r", "cc") # 404: GitHub knows no attestation
  end

  def test_repos_with_topic
    assert_equal ["o/x"], @github.repos_with_topic("o", "gregoiref-tap")
  end

  def test_download_follows_redirects
    Dir.mktmpdir do |dir|
      dest = @github.download("#{@base}/download/a.tar.gz", File.join(dir, "a"))
      assert_equal "archive bytes", File.binread(dest)
    end
    assert_equal ["/download/a.tar.gz", "/storage/a.tar.gz"], @server.requests.map { |r| r[:path] }
  end

  def test_read
    assert_equal "archive bytes", @github.read("#{@base}/storage/a.tar.gz")
  end

  def test_token_never_leaves_the_api_host
    other = Tap::GitHub.new(token: "secret", api: "http://localhost:#{@server.port}/api")
    other.read("#{@base}/storage/a.tar.gz")
    assert_nil @server.requests.last[:headers]["authorization"]
  end

  def test_errors
    assert_raises(Tap::Error) { @github.read("#{@base}/loop") }
    assert_raises(Tap::Error) { @github.read("#{@base}/boom") }
    assert_raises(Tap::Error) { @github.read("#{@base}/missing") }
  end
end
