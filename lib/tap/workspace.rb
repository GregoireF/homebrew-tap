# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "fileutils"
require "yaml"

module Tap
  # The checkout the commands work on, and what they share: its files, the
  # catalog, GitHub, the verifier, the output streams and $GITHUB_OUTPUT.
  # Files are read and written in binary mode: LF on every platform, so
  # `check` gives the same answer on Windows as in CI.
  class Workspace
    attr_reader :root, :out, :err

    def initialize(root: Targets::ROOT, out: $stdout, err: $stderr, github: nil, verifier: nil)
      @root = root
      @out = out
      @err = err
      @github = github
      @verifier = verifier
    end

    def github = @github ||= GitHub.new

    def verifier = @verifier ||= Verifier.new

    def path(rel) = File.join(root, rel)

    def read(rel)
      full = path(rel)
      File.binread(full).force_encoding(Encoding::UTF_8) if File.exist?(full)
    end

    # Writes only when the content changes; reports what it wrote.
    def write(rel, content)
      return if read(rel) == content

      full = path(rel)
      FileUtils.mkdir_p(File.dirname(full))
      File.binwrite(full, content)
      err.puts "wrote #{rel}"
    end

    def tools = Config.load(path("tools.yml"))

    def publisher = YAML.safe_load(read("tools.yml"))["publisher"]

    def lock = @lock ||= Lock.load(path("tools.lock.json"))

    def catalog(status: {}) = Catalog.new(tools:, lock:, readme: read("README.md") || "", status:)

    # Relative paths that exist under the globs of `targets`.
    def existing(targets)
      Targets.globs(targets).flat_map { |glob| Dir[path(glob)] }.map { |f| f.delete_prefix("#{root}/") }
    end

    def remove_empty_dirs(rel)
      Dir[path("#{rel}/**/")].sort_by { |d| -d.length }.each { |dir| Dir.rmdir(dir) if Dir.empty?(dir) }
    end

    # key<<EOF multi-line values for later steps of a GitHub Actions job.
    def output(**values)
      (file = ENV.fetch("GITHUB_OUTPUT", nil)) || return
      File.open(file, "ab") do |f|
        values.each do |key, value|
          delimiter = "EOF_#{key.upcase}"
          f.puts "#{key}<<#{delimiter}", value.to_s.chomp, delimiter
        end
      end
    end
  end
end
