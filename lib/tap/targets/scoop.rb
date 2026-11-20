# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "json"

module Tap
  module Targets
    # bucket/<name>.json: the Scoop manifest, Windows x64 and arm64 zips.
    module Scoop
      GLOBS = %w[bucket/*.json].freeze
      ARCHITECTURES = { "64bit" => "windows_amd64", "arm64" => "windows_arm64" }.freeze

      module_function

      def files(catalog)
        catalog.served.to_h { |tool, release| ["bucket/#{tool.name}.json", manifest(tool, release)] }
      end

      def manifest(tool, release)
        architecture = ARCHITECTURES.transform_values do |platform|
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
          "architecture" => architecture,
        }
        manifest["notes"] = tool.caveats if tool.caveats
        "#{JSON.pretty_generate(manifest)}\n"
      end
    end
  end
end
