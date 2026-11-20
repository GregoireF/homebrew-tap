# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

module Tap
  # The commit header rules of ship-it (ADR-0007), for the local commit-msg
  # hook: `✨ feat(scope): subject`, optional gitmoji, header at most 72
  # characters, subject at most 50. CI checks the same with ship itself.
  module CommitLint
    TYPES = %w[feat fix docs style refactor perf test build ci chore security revert wip].freeze
    HEADER = %r{\A(?:(?<emoji>[^\x00-\x7F]\S*) )?(?<type>[a-z]+)(?:\((?<scope>[\w./-]+)\))?!?: (?<subject>\S.*)\z}
    AI_TRAILER = /^Co-authored-by: .*(claude|anthropic|copilot|openai)/i
    HEADER_MAX = 72
    SUBJECT_MAX = 50
    # git's own messages, left alone.
    SKIP = /\A(?:Merge |Revert "|fixup! |squash! |amend! )/

    module_function

    # Problems with a commit message, empty when it is fine.
    def problems(message)
      header = message.each_line.map(&:chomp).find { |l| !l.start_with?("#") && !l.strip.empty? }.to_s
      return [] if header.match?(SKIP)

      match = HEADER.match(header)
      return ["header must look like `✨ feat(scope): subject`, got #{header.inspect}"] if match.nil?

      found = []
      found << "unknown type #{match[:type]} (#{TYPES.join(", ")})" unless TYPES.include?(match[:type])
      found << "header is #{header.length} characters, at most #{HEADER_MAX}" if header.length > HEADER_MAX
      if match[:subject].length > SUBJECT_MAX
        found << "subject is #{match[:subject].length} characters, at most #{SUBJECT_MAX}"
      end
      found << "subject must not end with a period" if match[:subject].end_with?(".")
      found << "remove the AI co-author trailer: the owner is the only author" if message.match?(AI_TRAILER)
      found
    end
  end
end
