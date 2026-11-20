# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "erb"
require "json"

module Tap
  # Turns tools.yml + tools.lock.json into the files the tap serves. Pure:
  # the same inputs always give the same bytes, which `bin/tap check` relies on.
  module Render
    ROOT = File.expand_path("../..", __dir__).freeze
    FORMULA = ERB.new(File.binread(File.join(ROOT, "templates/formula.rb.erb")).force_encoding("UTF-8"),
                      trim_mode: "-").freeze
    README_START = "<!-- BEGIN GENERATED: tools -->"
    README_END = "<!-- END GENERATED: tools -->"

    module_function

    # { relative path => content } for every generated file of the tap.
    def files(tools, lock, readme:)
      out = {}
      tools.each do |tool|
        (release = lock[tool.name]) || next
        out["Formula/#{tool.name}.rb"] = formula(tool, release)
        out["bucket/#{tool.name}.json"] = scoop(tool, release)
        out.merge!(Winget.files(tool, release)) if tool.winget
      end
      out["README.md"] = readme_section(readme, tools, lock)
      out
    end

    def formula(tool, release)
      FormulaContext.new(tool, release).render
    end

    def scoop(tool, release)
      arch = { "64bit" => "windows_amd64", "arm64" => "windows_arm64" }.transform_values do |platform|
        {
          "url"  => release.url(tool, platform),
          "hash" => release.sha256(platform),
          "bin"  => tool.binaries.map { |b| "#{b}.exe" },
        }
      end
      manifest = {
        "version"      => release.version,
        "description"  => tool.desc,
        "homepage"     => tool.homepage,
        "license"      => tool.license,
        "architecture" => arch,
      }
      manifest["notes"] = tool.caveats if tool.caveats
      "#{JSON.pretty_generate(manifest)}\n"
    end

    def readme_section(readme, tools, lock)
      (start = readme.index(README_START)) || raise(Error, "README.md: #{README_START} marker missing")
      (stop = readme.index(README_END)) || raise(Error, "README.md: #{README_END} marker missing")
      raise Error, "README.md: generated markers out of order" if stop < start

      "#{readme[0, start]}#{README_START}\n#{tools_table(tools, lock)}#{readme[stop..]}"
    end

    def tools_table(tools, lock)
      rows = tools.filter_map do |tool|
        (release = lock[tool.name]) || next
        badge = (release.verified == "attestation") ? "SLSA provenance" : "SHA-256"
        "| [`#{tool.name}`](#{tool.homepage}) | #{tool.desc} | " \
          "[#{release.version}](#{tool.homepage}/releases/tag/#{release.tag}) | " \
          "`brew install gregoiref/tap/#{tool.name}` | `scoop install gregoiref/#{tool.name}` | #{badge} |"
      end
      <<~MD

        | Tool | Description | Version | Homebrew | Scoop | Verified with |
        | --- | --- | --- | --- | --- | --- |
        #{rows.join("\n")}

      MD
    end

    # The bindings of templates/formula.rb.erb.
    class FormulaContext
      attr_reader :tool, :release

      def initialize(tool, release)
        @tool = tool
        @release = release
      end

      def render = FORMULA.result(binding)

      # A Ruby string literal (the formulae are Ruby).
      def q(text)
        %Q("#{text.gsub("\\", "\\\\\\\\").gsub('"', '\\"').gsub("#", "\\#")}")
      end

      def license_dsl
        parts = tool.license.split(/\s+(OR|AND)\s+/)
        return q(tool.license) if parts.size == 1

        ops = parts.values_at(*(1...parts.size).step(2))
        raise Error, "#{tool.name}: mixed OR/AND in license is not supported" if ops.uniq.size > 1

        ids = parts.values_at(*(0...parts.size).step(2))
        key = (ops.first == "OR") ? "any_of" : "all_of"
        "#{key}: [#{ids.map { |id| q id }.join(", ")}]"
      end

      def test_command
        args = tool.test.join(" ")
        %Q("\#{bin}/#{tool.binaries.first}#{" #{args}" unless args.empty?}")
      end
    end
  end
end
