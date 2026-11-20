# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "digest"
require "fileutils"
require "minitest"
require "stringio"
require "tmpdir"

# Line coverage of lib/ with the standard library (no gem): `rake test`
# fails under the floor. Started before lib/ loads.
if ENV["COVERAGE"] != "0"
  require "coverage"
  Coverage.start(lines: true)
  COVERAGE_FLOOR = 90.0

  Minitest.after_run do
    lib = File.expand_path("../lib", __dir__)
    files = Coverage.result.select { |path, _| path.start_with?(lib) }
    lines = files.values.flat_map { |r| r[:lines].compact }
    percent = lines.empty? ? 0.0 : 100.0 * lines.count(&:positive?) / lines.size
    files.each do |path, r|
      missed = r[:lines].each_with_index.select { |hits, _| hits&.zero? }.map { |_, i| i + 1 }
      warn "  #{path.delete_prefix("#{lib}/")}: lines #{missed.join(", ")} not covered" unless missed.empty?
    end
    warn format("coverage: %<percent>.1f%% of lib/ (floor %<floor>.0f%%)", percent:, floor: COVERAGE_FLOOR)
    exit 1 if percent < COVERAGE_FLOOR
  end
end

require "minitest/autorun"
require_relative "../lib/tap"

module TestHelpers
  ROOT = File.expand_path("..", __dir__).freeze
  GOLDEN = File.join(__dir__, "golden").freeze

  def tool(**overrides)
    Tap::Tool.new(name: "demo", repo: "GregoireF/demo", desc: "Demonstrates the tap", license: "MIT",
                  binaries: ["demo"], test: ["--version"], verify: "attestation", checksums: "checksums.txt",
                  assets: Tap::PLATFORMS.to_h do |p|
                    [p, p.start_with?("windows") ? "demo_{version}_#{p}.zip" : "demo_{version}_#{p}.tar.gz"]
                  end,
                  caveats: nil, completions: nil, winget: nil, publisher: nil, **overrides)
  end

  def release(version = "1.2.3", tool: self.tool)
    assets = Tap::PLATFORMS.to_h do |p|
      [p, { "name" => tool.asset_name(p, version), "sha256" => Digest::SHA256.hexdigest(p) }]
    end
    Tap::Release.new(tag: "v#{version}", version:, verified: tool.verify, assets:, published: nil)
  end

  def catalog(tools, lock, readme: "") = Tap::Catalog.new(tools:, lock:, readme:)

  # Every committed file the repository targets produce for these inputs.
  def repository_files(tools, lock, readme:)
    Tap::Targets.files(Tap::Targets.repository, catalog(tools, lock, readme:))
  end

  # Compares with test/golden/<name>; UPDATE_GOLDEN=1 rewrites the file.
  def assert_golden(name, actual)
    path = File.join(GOLDEN, name)
    if ENV["UPDATE_GOLDEN"] == "1"
      FileUtils.mkdir_p(GOLDEN)
      File.binwrite(path, actual)
    end
    assert_equal File.binread(path).force_encoding(Encoding::UTF_8), actual, "golden #{name} differs"
  end

  # Serves releases from memory instead of api.github.com.
  class FakeGitHub
    attr_reader :downloads

    # releases: { repo => { tag:, published:, files: { name => bytes } } }
    # repos:    { repo => { description:, license:, topics: } }
    # attested: SHA-256 digests GitHub holds a provenance for.
    def initialize(releases, repos: {}, attested: [])
      @releases = releases
      @repos = repos
      @attested = attested
      @downloads = []
    end

    def latest_release(repo)
      (r = @releases[repo]) || return
      { tag: r[:tag], published: r[:published],
        assets: r[:files].keys.to_h { |name| [name, "fake://#{repo}/#{name}"] } }
    end

    def repository(repo) = @repos.fetch(repo)

    def attested?(_repo, sha256) = @attested.include?(sha256)

    def read(url) = bytes(url)

    def repos_with_topic(_owner, _topic) = @releases.keys

    def download(url, dest)
      @downloads << url
      File.binwrite(dest, bytes(url))
      dest
    end

    private

    def bytes(url)
      repo, name = url.delete_prefix("fake://").split("/", 3).then { |o, r, n| ["#{o}/#{r}", n] }
      @releases.fetch(repo)[:files].fetch(name)
    end
  end

  class FakeVerifier
    attr_reader :checked

    def initialize(reject: [])
      @reject = reject
      @checked = []
    end

    def check_attestation(path, repo)
      name = File.basename(path)
      raise Tap::Error, "#{name}: no valid provenance from #{repo}" if @reject.include?(name)

      @checked << name
    end
  end
end
