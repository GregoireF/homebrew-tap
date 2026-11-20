# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "json"

module Tap
  # Writes a tools.yml entry from a repository's latest stable release:
  # archive per platform, checksums file, binary name, licence and the
  # strongest verification level the release supports. Used by
  # `bin/tap add <repo>` and, for repositories with the gregoiref-tap topic,
  # by `bin/tap discover --add` in sync.yml. Anything it cannot infer with
  # certainty is an error: a human then writes the entry.
  class Onboard
    OS = {
      "darwin"  => /darwin|apple|macos|osx/i,
      "linux"   => /linux/i,
      "windows" => /windows|win64|pc-windows|_win_|-win-/i,
    }.freeze
    ARCH = {
      "amd64" => /amd64|x86_64|x64/i,
      "arm64" => /arm64|aarch64/i,
    }.freeze
    UNIX_ARCHIVE = /\.(?:tar\.gz|tgz|tar\.xz)\z/
    WINDOWS_ARCHIVE = /\.zip\z/
    CHECKSUMS = /\A(?:checksums\.txt|sha256\.sum|sha256sums(?:\.txt)?|.*[-_]checksums\.txt)\z/i
    DEFAULT_TEST = ["--version"].freeze
    # The archives' common leading word: ship_0.1.2_linux_amd64 → ship.
    LEADING_WORD = /\A[a-z0-9]+(?:-[a-z]+)*?(?=[-_](?:v?\d|darwin|linux|windows|x86_64|aarch64|amd64|arm64))/i

    def initialize(github:, publisher: nil)
      @github = github
      @publisher = publisher
    end

    # [name, entry] where entry has the keys of tools.yml.
    def entry(repo)
      latest = @github.latest_release(repo) || raise(Error, "#{repo}: no stable release to add")
      version = latest[:tag].delete_prefix("v")
      names = latest[:assets].keys

      assets = PLATFORMS.to_h { |platform| [platform, pick(repo, platform, names)] }
      checksums = names.find { |n| n.match?(CHECKSUMS) } || raise(Error, "#{repo}: no checksums file in the release")
      binary = binary_name(repo, assets.values)
      meta = @github.repository(repo)

      entry = {
        "repo"      => repo,
        "desc"      => description(repo, binary, meta[:description]),
        "license"   => license(repo, meta[:license]),
        "binaries"  => [binary],
        "test"      => DEFAULT_TEST.dup,
        "verify"    => verify_level(repo, latest, checksums, assets["linux_amd64"]),
        "checksums" => checksums,
      }
      entry["winget"] = "#{repo.split("/").first}.#{binary}" if @publisher
      entry["assets"] = assets.transform_values { |name| name.gsub(version, "{version}") }
      Config.build(binary, entry, "tools.yml", publisher: @publisher) # same rules as the file
      [binary, entry]
    end

    # The entry as YAML lines to append under `tools:` (keeps the file's comments).
    def self.yaml(name, entry)
      lines = ["", "  #{name}:"]
      entry.each do |key, value|
        case value
        when Array then lines << "    #{key}: [#{value.map { |v| scalar(v) }.join(", ")}]"
        when Hash
          lines << "    #{key}:"
          value.each { |k, v| lines << "      #{k}: #{scalar(v)}" }
        else lines << "    #{key}: #{scalar(value)}"
        end
      end
      "#{lines.join("\n")}\n"
    end

    def self.scalar(value)
      text = value.to_s
      # (`index(...).nil?`, not `!include?`: Homebrew's style wants `exclude?`,
      # which plain Ruby does not have.)
      plain = text.match?(%r!\A[A-Za-z0-9{][\w.{}/+ -]*\z!) && text.index(": ").nil? && !text.end_with?(" ")
      plain ? text : JSON.generate(text)
    end

    def pick(repo, platform, names)
      os, arch = platform.split("_")
      ext = (os == "windows") ? WINDOWS_ARCHIVE : UNIX_ARCHIVE
      found = names.select { |n| n.match?(ext) && n.match?(OS.fetch(os)) && n.match?(ARCH.fetch(arch)) }
      # glibc over musl, then the shortest name (no "-debug", "-full" variants).
      found = found.reject { |n| n.include?("musl") } if found.size > 1
      found.min_by { |n| [n.length, n] } || raise(Error, "#{repo}: no #{ext.source} archive for #{platform}")
    end

    def binary_name(repo, archives)
      words = archives.map { |a| a[LEADING_WORD] }
      name = words.first&.downcase if words.uniq.size == 1
      name || raise(Error, "#{repo}: cannot tell the binary's name from #{archives.first}")
    end

    # attestation when GitHub holds a provenance for the linux_amd64 archive.
    def verify_level(repo, latest, checksums, archive)
      sums = Checksums.parse(@github.read(latest[:assets].fetch(checksums)))
      sha = sums[archive] || raise(Error, "#{repo}: #{checksums} does not list #{archive}")
      @github.attested?(repo, sha) ? "attestation" : "checksum"
    end

    private

    def description(repo, name, text)
      desc = text.strip.sub(/\A(?:an?|the)\s+/i, "").sub(/[.!\s]+\z/, "")
      desc = "#{desc[0].upcase}#{desc[1..]}" unless desc.empty?
      desc = shorten(desc) if desc.length > 80
      raise Error, "#{repo}: the repository description starts with #{name}; write desc by hand" if
        desc.downcase.start_with?("#{name} ")

      desc
    end

    # Up to the first ":", " — " or sentence end when that leaves a phrase;
    # otherwise the last whole words that fit in 80 characters.
    def shorten(desc)
      head = desc.split(/: | — | - |\. /, 2).first
      return head if head.length.between?(20, 80)

      desc[0, 81].sub(/\s+\S*\z/, "").sub(/[\s,;:]+\z/, "")
    end

    def license(repo, spdx)
      raise Error, "#{repo}: GitHub does not know the licence; write license by hand" if
        spdx.nil? || spdx == "NOASSERTION"

      spdx
    end
  end
end
