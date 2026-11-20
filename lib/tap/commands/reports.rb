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

    # `site DIR`: every site target, written into DIR (the Pages artifact).
    class Site < Base
      def call(args)
        dir = arg(args, 0, "site DIR")
        Targets.files(Targets.site, ws.catalog).each do |rel, content|
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
