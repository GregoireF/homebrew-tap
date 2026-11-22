# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "yaml"

module Tap
  class Error < StandardError; end

  PLATFORMS = %w[darwin_amd64 darwin_arm64 linux_amd64 linux_arm64 windows_amd64 windows_arm64].freeze
  VERIFY_LEVELS = %w[checksum attestation].freeze

  # One entry of tools.yml (plus the file's top-level `publisher`).
  Tool = Data.define(:name, :repo, :desc, :license, :binaries, :test, :verify, :checksums, :assets,
                     :caveats, :completions, :winget, :formula, :conflicts, :pin, :nested, :publisher) do
    # The Homebrew formula's name: `formula` when the tool's own name is
    # taken in homebrew-core, the tool's name otherwise.
    define_method(:formula_name) do
      formula || name
    end

    # Homebrew's class name for the formula name (Formulary.class_s).
    define_method(:class_name) do
      formula_name.capitalize.gsub(/[-_.\s]([a-zA-Z0-9])/) { Regexp.last_match(1).upcase }.tr("+", "x")
    end

    define_method(:homepage) do
      "https://github.com/#{repo}"
    end

    define_method(:asset_name) do |platform, version|
      assets.fetch(platform).gsub("{version}", version)
    end
  end.freeze

  # Loads and validates tools.yml. schema/tools.schema.json describes the same
  # rules for editors; test/schema_test.rb keeps the two in step.
  module Config
    OPTIONAL = %w[caveats completions winget formula conflicts pin nested].freeze
    KEYS = (%w[repo desc license binaries test verify checksums assets] + OPTIONAL).freeze
    REQUIRED = (KEYS - OPTIONAL).freeze
    TOP_LEVEL = %w[publisher tools].freeze
    NAME = /\A[a-z0-9][a-z0-9-]*\z/
    VERSION = /\A\d+(?:\.\d+)*(?:[-+][0-9A-Za-z.-]+)?\z/
    WINGET_ID = /\A[A-Za-z0-9][\w-]*\.[A-Za-z0-9][\w.-]*\z/

    module_function

    def load(path)
      data = YAML.safe_load_file(path)
      raise Error, "#{path}: top-level key `tools` missing" if !data.is_a?(Hash) || !data["tools"].is_a?(Hash)

      unknown = data.keys - TOP_LEVEL
      raise Error, "#{path}: unknown top-level keys #{unknown.join(", ")}" unless unknown.empty?

      data["tools"].sort.map { |name, entry| build(name, entry, path, publisher: data["publisher"]) }
    end

    def build(name, entry, path, publisher: nil)
      where = "#{path}: tools.#{name}"
      raise Error, "#{where}: not a mapping" unless entry.is_a?(Hash)

      check_keys(entry, where)
      check_values(name, entry, where)
      check_optional(entry, where, publisher)
      Tool.new(
        name:, repo: entry["repo"], desc: entry["desc"], license: entry["license"],
        binaries: entry["binaries"].freeze, test: entry["test"].freeze, verify: entry["verify"],
        checksums: entry["checksums"], assets: entry["assets"].freeze, caveats: entry["caveats"],
        completions: entry["completions"]&.freeze, winget: entry["winget"], formula: entry["formula"],
        conflicts: entry.fetch("conflicts", []).freeze, pin: entry["pin"], nested: entry.fetch("nested", false),
        publisher:
      )
    end

    def check_keys(entry, where)
      unknown = entry.keys - KEYS
      raise Error, "#{where}: unknown keys #{unknown.join(", ")}" unless unknown.empty?

      missing = REQUIRED - entry.keys
      raise Error, "#{where}: missing keys #{missing.join(", ")}" unless missing.empty?
    end

    def check_values(name, entry, where)
      raise Error, "#{where}: name must match [a-z0-9-]+" unless name.match?(NAME)
      raise Error, "#{where}.repo: expected owner/name" unless entry["repo"].to_s.match?(%r{\A[\w.-]+/[\w.-]+\z})

      check_desc(name, entry["desc"].to_s, where)
      unless VERIFY_LEVELS.include?(entry["verify"])
        raise Error, "#{where}.verify: expected one of #{VERIFY_LEVELS.join(", ")}"
      end

      %w[binaries test].each { |key| check_strings(entry[key], "#{where}.#{key}") }
      raise Error, "#{where}.binaries: empty" if entry["binaries"].empty?

      assets = entry["assets"]
      raise Error, "#{where}.assets: not a mapping" unless assets.is_a?(Hash)

      missing = PLATFORMS - assets.keys
      extra = assets.keys - PLATFORMS
      raise Error, "#{where}.assets: missing #{missing.join(", ")}" unless missing.empty?
      raise Error, "#{where}.assets: unknown platforms #{extra.join(", ")}" unless extra.empty?
    end

    def check_optional(entry, where, publisher)
      if entry.key?("completions")
        check_strings(entry["completions"], "#{where}.completions")
        raise Error, "#{where}.completions: empty" if entry["completions"].empty?
      end
      if entry.key?("formula") && !entry["formula"].to_s.match?(NAME)
        raise Error, "#{where}.formula: must match [a-z0-9-]+"
      end

      if entry.key?("pin") && !(entry["pin"].is_a?(String) && entry["pin"].match?(VERSION))
        raise Error, "#{where}.pin: expected a quoted version like \"1.2.3\""
      end

      if entry.key?("nested") && entry["nested"] != true && entry["nested"] != false
        raise Error, "#{where}.nested: expected true or false"
      end

      if entry.key?("conflicts")
        check_strings(entry["conflicts"], "#{where}.conflicts")
        bad = entry["conflicts"].grep_v(NAME)
        raise Error, "#{where}.conflicts: not formula names: #{bad.join(", ")}" unless bad.empty?
      end
      return unless entry.key?("winget")

      id = entry["winget"].to_s
      raise Error, "#{where}.winget: expected a package identifier like Publisher.Name" unless id.match?(WINGET_ID)
      raise Error, "#{where}.winget: needs a top-level `publisher`" if publisher.to_s.empty?
    end

    def check_strings(list, where)
      raise Error, "#{where}: expected a list of strings" if !list.is_a?(Array) || !list.all?(String)
    end

    # The rules `brew audit` applies to desc (FormulaAudit/Desc cop).
    def check_desc(name, desc, where)
      problems = []
      problems << "longer than 80 characters" if desc.length > 80
      problems << "ends with a period" if desc.end_with?(".")
      problems << "starts with an article" if desc.match?(/\A(an?|the)\s/i)
      problems << "starts with the tool's name" if desc.downcase.start_with?("#{name.downcase} ")
      problems << "is empty" if desc.empty?
      raise Error, "#{where}.desc: #{problems.join(", ")}" unless problems.empty?
    end
  end
end
