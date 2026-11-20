# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

# Homebrew/SingleUseMethod is for Homebrew's own code; this generator keeps
# named steps for readability and tests (AGENTS.md).
# rubocop:disable Homebrew/SingleUseMethod

require "digest"
require "rubygems"
require "tmpdir"

module Tap
  # Brings tools.lock.json up to date with the latest stable releases.
  # Every archive is downloaded and hashed here: the SHA-256 that ends up in a
  # formula is the one of the bytes the tap saw, cross-checked with the
  # release's checksums file and, for `verify: attestation`, with its signed
  # build provenance.
  class Sync
    VERSION = /\A\d+(?:\.\d+)*(?:[-+][0-9A-Za-z.-]+)?\z/

    Update = Data.define(:tool, :from, :to).freeze

    def initialize(lock:, github: GitHub.new, verifier: Verifier.new, log: $stderr)
      @lock = lock
      @github = github
      @verifier = verifier
      @log = log
    end

    # Returns the list of Updates; the lock is changed in memory only.
    def run(tools)
      tools.filter_map { |tool| sync(tool) }
    end

    def sync(tool)
      latest = @github.latest_release(tool.repo)
      if latest.nil?
        @log.puts "#{tool.name}: no stable release yet"
        return
      end

      current = @lock[tool.name]
      return if current && current.tag == latest[:tag] && current.verified == tool.verify

      version = version_of(tool, latest[:tag])
      refuse_downgrade(tool, current, version)

      @log.puts "#{tool.name}: #{current&.version || "none"} -> #{version}"
      @lock[tool.name] = fetch_release(tool, latest, version)
      Update.new(tool: tool.name, from: current&.version, to: version)
    end

    private

    def version_of(tool, tag)
      version = tag.delete_prefix("v")
      raise Error, "#{tool.name}: tag #{tag} is not a version" unless version.match?(VERSION)

      version
    end

    def refuse_downgrade(tool, current, version)
      return if current.nil?
      return if Gem::Version.new(version) >= Gem::Version.new(current.version)

      raise Error, "#{tool.name}: latest release #{version} is older than #{current.version}, refusing to downgrade"
    end

    def fetch_release(tool, latest, version)
      sums = checksums(tool, latest)
      Dir.mktmpdir("tap-#{tool.name}") do |dir|
        assets = PLATFORMS.to_h do |platform|
          name = tool.asset_name(platform, version)
          [platform, { "name" => name, "sha256" => fetch_asset(tool, latest, name, sums, dir) }]
        end
        Release.new(tag: latest[:tag], version:, verified: tool.verify, assets:, published: latest[:published])
      end
    end

    def checksums(tool, latest)
      (url = latest[:assets][tool.checksums]) ||
        raise(Error, "#{tool.name} #{latest[:tag]}: release has no #{tool.checksums}")
      Checksums.parse(@github.read(url))
    end

    def fetch_asset(tool, latest, name, sums, dir)
      (url = latest[:assets][name]) || raise(Error, "#{tool.name} #{latest[:tag]}: release has no #{name}")
      (expected = sums[name]) || raise(Error, "#{tool.name} #{latest[:tag]}: #{tool.checksums} does not list #{name}")

      path = @github.download(url, File.join(dir, name))
      actual = Digest::SHA256.file(path).hexdigest
      if actual != expected
        raise Error, "#{tool.name} #{latest[:tag]}: #{name} has SHA-256 #{actual}, #{tool.checksums} says #{expected}"
      end

      @verifier.check_attestation(path, tool.repo) if tool.verify == "attestation"
      actual
    end
  end
end

# rubocop:enable Homebrew/SingleUseMethod
