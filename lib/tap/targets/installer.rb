# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

module Tap
  module Targets
    # install.sh on the site: a POSIX script with every served archive's URL
    # and SHA-256 inside, for macOS and Linux machines without Homebrew. It
    # checks the SHA-256 always and the SLSA provenance when it can.
    module Installer
      GLOBS = [].freeze
      UNIX = %w[darwin_amd64 darwin_arm64 linux_amd64 linux_arm64].freeze
      TEMPLATE = Targets.template("site/install.sh.erb").freeze

      module_function

      def files(catalog) = { "install.sh" => script(catalog.served) }

      def script(served)
        context = Object.new
        context.define_singleton_method(:served) { served }
        context.define_singleton_method(:url) { Pages::URL }
        context.define_singleton_method(:unix) { UNIX }
        context.define_singleton_method(:sh) { |text| Installer.sh(text) }
        context.instance_eval { TEMPLATE.result(binding) }
      end

      # A single-quoted shell word.
      def sh(text)
        escaped = text.to_s.gsub("'", "'\\\\''")
        "'#{escaped}'"
      end
    end
  end
end
