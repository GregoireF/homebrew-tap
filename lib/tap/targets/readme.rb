# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

module Tap
  module Targets
    # The tools table of README.md, between the GENERATED markers; the rest of
    # the README stays hand-written.
    module Readme
      GLOBS = [].freeze
      START = "<!-- BEGIN GENERATED: tools -->"
      STOP = "<!-- END GENERATED: tools -->"

      module_function

      def files(catalog) = { "README.md" => section(catalog) }

      def section(catalog)
        readme = catalog.readme
        (start = readme.index(START)) || raise(Error, "README.md: #{START} marker missing")
        (stop = readme.index(STOP)) || raise(Error, "README.md: #{STOP} marker missing")
        raise Error, "README.md: generated markers out of order" if stop < start

        "#{readme[0, start]}#{START}\n#{table(catalog)}#{readme[stop..]}"
      end

      def table(catalog)
        rows = catalog.served.map do |tool, release|
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
    end
  end
end
