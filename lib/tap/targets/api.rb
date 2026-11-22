# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "json"

module Tap
  module Targets
    # The public JSON API of the catalog, versioned under /api/v1/ and
    # described by schema/api.schema.json (served as /api/v1/schema.json):
    #
    #   api/v1/tools.json          every served tool, one summary each
    #   api/v1/tools/<name>.json   one tool: archives, checksums, install commands
    #
    # Tools that read it never parse formulae or HTML.
    module Api
      GLOBS = [].freeze
      SCHEMA = File.join(Targets::ROOT, "schema/api.schema.json").freeze

      module_function

      def base = "#{Pages::URL}/api/v1"

      def files(catalog)
        served = catalog.served
        out = {
          "api/v1/schema.json" => File.binread(SCHEMA).force_encoding(Encoding::UTF_8),
          "api/v1/tools.json"  => json("$schema" => "#{base}/schema.json",
                                       "tools"   => served.map { |tool, release| summary(tool, release) }),
        }
        served.each { |tool, release| out["api/v1/tools/#{tool.name}.json"] = json(tool(tool, release)) }
        out
      end

      def summary(tool, release)
        {
          "name"      => tool.name,
          "desc"      => tool.desc,
          "version"   => release.version,
          "published" => release.published,
          "verified"  => release.verified,
          "url"       => "#{base}/tools/#{tool.name}.json",
        }
      end

      def tool(tool, release)
        {
          "$schema"   => "#{base}/schema.json",
          "name"      => tool.name,
          "desc"      => tool.desc,
          "homepage"  => tool.homepage,
          "license"   => tool.license,
          "version"   => release.version,
          "tag"       => release.tag,
          "published" => release.published,
          "verified"  => release.verified,
          "binaries"  => tool.binaries,
          "archives"  => PLATFORMS.to_h do |p|
            [p, { "url" => release.url(tool, p), "sha256" => release.sha256(p) }]
          end,
          "install"   => install(tool),
        }
      end

      # The command per package manager; WinGet only when the tool has an id.
      def install(tool)
        out = {
          "homebrew"  => "brew install gregoiref/tap/#{tool.formula_name}",
          "scoop"     => "scoop install gregoiref/#{tool.name}",
          "installer" => "curl -fsSL #{Pages::URL}/install.sh | sh -s -- #{tool.name}",
        }
        out["winget"] = "winget install --id #{tool.winget} --exact" if tool.winget
        out
      end

      def json(data) = "#{JSON.pretty_generate(data)}\n"
    end
  end
end
