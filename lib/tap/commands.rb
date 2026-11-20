# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

module Tap
  # One class per `bin/tap` command. Each takes the workspace, receives its
  # arguments and returns the exit status.
  module Commands
    # What every command has: the workspace and a usage line for errors.
    class Base
      def initialize(workspace)
        @ws = workspace
      end

      attr_reader :ws

      def arg(args, index, usage)
        args.fetch(index) { raise Error, "usage: bin/tap #{usage}" }
      end
    end
  end
end
