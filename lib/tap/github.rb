# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Tap
  # The few GitHub REST calls the tap needs. Reads GH_TOKEN or GITHUB_TOKEN
  # when set (higher rate limit); public repositories need no token.
  class GitHub
    API = "https://api.github.com"
    MAX_REDIRECTS = 5

    def initialize(token: ENV["GH_TOKEN"] || ENV.fetch("GITHUB_TOKEN", nil), api: API)
      @token = token
      @api = api
      @api_host = URI(api).host
    end

    # The latest stable release (GitHub never returns drafts or pre-releases
    # here): { tag:, published:, assets: { name => download URL } }, or nil.
    def latest_release(repo)
      body = get_json("#{@api}/repos/#{repo}/releases/latest")
      return if body.nil?

      assets = body.fetch("assets").to_h { |a| [a.fetch("name"), a.fetch("browser_download_url")] }
      { tag: body.fetch("tag_name"), published: body["published_at"], assets: }
    end

    # Repository metadata: { description:, license: SPDX id or nil, topics: }.
    def repository(repo)
      body = get_json("#{@api}/repos/#{repo}") || raise(Error, "#{repo}: repository not found")
      { description: body["description"].to_s, license: body.dig("license", "spdx_id"),
        topics: body.fetch("topics", []) }
    end

    # True when GitHub stores at least one attestation for this SHA-256 in repo.
    def attested?(repo, sha256)
      body = get_json("#{@api}/repos/#{repo}/attestations/sha256:#{sha256}?per_page=1")
      !body.nil? && !body.fetch("attestations", []).empty?
    end

    # Repositories of `owner` carrying `topic`, for discovery.
    def repos_with_topic(owner, topic)
      query = URI.encode_www_form_component("user:#{owner} topic:#{topic}")
      body = get_json("#{@api}/search/repositories?q=#{query}") || { "items" => [] }
      body.fetch("items").map { |r| r.fetch("full_name") }
    end

    def download(url, dest)
      fetch(URI(url), MAX_REDIRECTS) do |response|
        File.open(dest, "wb") { |f| response.read_body { |chunk| f.write(chunk) } }
      end
      dest
    end

    def read(url)
      out = +""
      fetch(URI(url), MAX_REDIRECTS) { |response| response.read_body { |chunk| out << chunk } }
      out
    end

    private

    def get_json(url)
      body = nil
      fetch(URI(url), MAX_REDIRECTS, accept: "application/vnd.github+json", allow_missing: true) do |response|
        body = JSON.parse(response.read_body)
      end
      body
    end

    def fetch(uri, redirects, accept: "application/octet-stream", allow_missing: false, &block)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = accept
      request["User-Agent"] = "homebrew-tap-sync"
      # The token goes to the API host only, never to the storage hosts
      # GitHub redirects downloads to.
      if uri.host == @api_host
        request["X-GitHub-Api-Version"] = "2022-11-28"
        request["Authorization"] = "Bearer #{@token}" if @token
      end

      status, location = request(uri, request, &block)
      case status
      when :redirect
        raise Error, "too many redirects for #{uri}" if redirects.zero?

        fetch(URI.join(uri.to_s, location), redirects - 1, accept:, allow_missing:, &block)
      when :missing
        raise Error, "GET #{uri}: 404" unless allow_missing
      end
    end

    # Yields a successful response; returns [:ok], [:redirect, location] or [:missing].
    def request(uri, request)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request) do |response|
          case response
          when Net::HTTPSuccess then yield response
          when Net::HTTPRedirection then return [:redirect, response["location"]]
          when Net::HTTPNotFound then return [:missing]
          else raise Error, "GET #{uri}: #{response.code} #{response.message}"
          end
        end
      end
      [:ok]
    end
  end
end
