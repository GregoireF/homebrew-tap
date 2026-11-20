# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

module Tap
  module Targets
    # Formula/<name>.rb from templates/formula.rb.erb: prebuilt archives per
    # macOS/Linux platform, livecheck, completions, a version assertion test.
    module Homebrew
      GLOBS = %w[Formula/*.rb].freeze
      TEMPLATE = Targets.template("formula.rb.erb").freeze

      module_function

      def files(catalog)
        catalog.served.to_h { |tool, release| ["Formula/#{tool.name}.rb", formula(tool, release)] }
      end

      def formula(tool, release) = Context.new(tool, release).render

      # The bindings of templates/formula.rb.erb.
      class Context
        attr_reader :tool, :release

        def initialize(tool, release)
          @tool = tool
          @release = release
        end

        def render = TEMPLATE.result(binding)

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
end
