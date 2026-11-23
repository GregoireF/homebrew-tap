# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

module Tap
  module Targets
    # flake.nix: one Nix package per tool and system, from the verified
    # release archives (`nix run github:GregoireF/homebrew-tap#kiwa`).
    # flake.lock, which pins nixpkgs, is Nix's own file and is not generated.
    module Nix
      GLOBS = %w[flake.nix].freeze
      UNIX = %w[linux_amd64 linux_arm64 darwin_amd64 darwin_arm64].freeze
      TEMPLATE = Targets.template("flake.nix.erb").freeze

      module_function

      def files(catalog)
        served = catalog.served
        return {} if served.empty?

        context = Object.new
        context.define_singleton_method(:served) { served }
        context.define_singleton_method(:unix) { UNIX }
        context.define_singleton_method(:nix) { |text| Nix.string(text) }
        context.define_singleton_method(:sri) { |hex| Nix.sri(hex) }
        { "flake.nix" => context.instance_eval { TEMPLATE.result(binding) } }
      end

      # A Nix string literal: ", \ and ${ escaped.
      def string(text)
        escaped = text.to_s.gsub("\\", "\\\\\\\\").gsub('"', '\\"').gsub("${", "\\${")
        "\"#{escaped}\""
      end

      # The SRI form Nix wants for a hex SHA-256.
      def sri(hex)
        digest = [hex].pack("H*")
        "sha256-#{[digest].pack("m0")}"
      end
    end
  end
end
