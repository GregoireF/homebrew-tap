# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "json"

module Tap
  module Targets
    # shields.io endpoint badges (https://shields.io/badges/endpoint-badge),
    # one JSON per tool and kind under badges/<name>/:
    #
    #   homebrew.json scoop.json      the version served
    #   provenance.json               SLSA verified or SHA-256 only
    #   install-tests.json            the last nightly install test on main
    #
    # In a README: https://img.shields.io/endpoint?url=<site>/badges/kiwa/homebrew.json
    module Badges
      GLOBS = [].freeze
      INSTALL_TESTS = {
        "passing" => ["6 platforms passing", "brightgreen"],
        "failing" => ["failing", "red"],
        nil       => ["unknown", "lightgrey"],
      }.freeze

      module_function

      def files(catalog)
        catalog.served.each_with_object({}) do |(tool, release), out|
          dir = "badges/#{tool.name}"
          out["#{dir}/homebrew.json"] = badge("homebrew", release.version, "orange")
          out["#{dir}/scoop.json"] = badge("scoop", release.version, "blue")
          out["#{dir}/provenance.json"] = provenance(release)
          message, color = INSTALL_TESTS.fetch(catalog.status["install_tests"], INSTALL_TESTS[nil])
          out["#{dir}/install-tests.json"] = badge("install tests", message, color)
        end
      end

      def provenance(release)
        if release.verified == "attestation"
          badge("provenance", "SLSA verified", "brightgreen")
        else
          badge("provenance", "SHA-256 only", "yellow")
        end
      end

      def badge(label, message, color)
        "#{JSON.generate("schemaVersion" => 1, "label" => label, "message" => message, "color" => color)}\n"
      end

      # The Markdown a tool's README pastes, one image per badge.
      def markdown(tool)
        base = "https://img.shields.io/endpoint?url=#{Pages::URL}/badges/#{tool.name}"
        %w[homebrew scoop provenance install-tests].map do |kind|
          "[![#{kind}](#{base}/#{kind}.json)](#{Pages::URL}/#{tool.name}/)"
        end.join("\n")
      end
    end
  end
end
