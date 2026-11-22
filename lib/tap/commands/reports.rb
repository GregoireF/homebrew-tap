# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "fileutils"

module Tap
  module Commands
    # `health`: stale tools and provenance problems; exit 1 when there are any.
    class Health < Base
      def call(_args)
        findings = Tap::Health.new(github: ws.github).run(ws.tools, ws.lock)
        report = Tap::Health.report(findings)
        ws.out.print report
        ws.output(report:)
        findings.empty? ? 0 : 1
      end
    end

    # `site DIR [--install-tests passing|failing]`: every site target, written
    # into DIR (the Pages artifact). The workflow passes the last nightly
    # install test's result, which the badges show.
    class Site < Base
      STATES = %w[passing failing].freeze

      def call(args)
        dir = arg(args, 0, "site DIR [--install-tests passing|failing]")
        status = {}
        if (i = args.index("--install-tests"))
          state = arg(args, i + 1, "site DIR --install-tests passing|failing")
          raise Error, "--install-tests: expected #{STATES.join(" or ")}, got #{state}" unless STATES.include?(state)

          status["install_tests"] = state
        end
        Targets.files(Targets.site, ws.catalog(status:)).each do |rel, content|
          full = File.join(dir, rel)
          FileUtils.mkdir_p(File.dirname(full))
          File.binwrite(full, content)
        end
        ws.err.puts "wrote the site to #{dir}"
        0
      end
    end

    # `lint-commit FILE`: the commit-msg hook.
    class LintCommit < Base
      def call(args)
        file = arg(args, 0, "lint-commit FILE")
        problems = CommitLint.problems(File.binread(file).force_encoding(Encoding::UTF_8))
        problems.each { |p| ws.err.puts "commit message: #{p}" }
        problems.empty? ? 0 : 1
      end
    end
  end
end
