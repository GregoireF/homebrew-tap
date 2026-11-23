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
        catalog.served.to_h { |tool, release| ["Formula/#{tool.formula_name}.rb", formula(tool, release)] }
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
          escaped = text.gsub("\\", "\\\\\\\\").gsub('"', '\\"').gsub("#", "\\#")
          %Q("#{escaped}")
        end

        def license_dsl
          parts = tool.license.split(/\s+(OR|AND)\s+/)
          return q(tool.license) if parts.size == 1

          ops = parts.values_at(*(1...parts.size).step(2))
          raise Error, "#{tool.name}: mixed OR/AND in license is not supported" if ops.uniq.size > 1

          ids = parts.values_at(*(0...parts.size).step(2))
          any = ops.first == "OR"
          key = any ? "any_of" : "all_of"
          quoted = ids.map { |id| q id }.join(", ")
          "#{key}: [#{quoted}]"
        end

        def test_command
          words = ["\#{bin}/#{tool.binaries.first}", *tool.test]
          %Q("#{words.join(" ")}")
        end
      end
    end
  end
end
