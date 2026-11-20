# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

module Tap
  # bin/tap: dispatches to Commands::*.
  class CLI
    COMMANDS = {
      "sync"        => Commands::Sync,
      "render"      => Commands::Render,
      "check"       => Commands::Check,
      "add"         => Commands::Add,
      "discover"    => Commands::Discover,
      "health"      => Commands::Health,
      "site"        => Commands::Site,
      "lint-commit" => Commands::LintCommit,
    }.freeze

    USAGE = <<~TXT
      usage: bin/tap <command>

        sync               fetch the latest stable releases, verify them, update
                           tools.lock.json and rewrite the generated files
        render             rewrite the generated files from tools.yml and the lock
        check              fail if a generated file differs from what render writes
        add REPO           append a tools.yml entry inferred from REPO's latest release
        discover [--add]   list (or add) repositories with the gregoiref-tap topic
                           that are not in tools.yml yet
        health             report stale tools and provenance problems (exit 1 if any)
        site DIR           write the catalog site into DIR
        lint-commit FILE   check a commit message (the commit-msg hook)

      sync writes `changed`, `tools` and `message` to $GITHUB_OUTPUT when set;
      health writes `report`.
    TXT

    def initialize(**workspace)
      @ws = Workspace.new(**workspace)
    end

    def run(argv)
      name, *args = argv
      command = COMMANDS[name]
      return usage(name) if command.nil?

      command.new(@ws).call(args)
    rescue Error => e
      @ws.err.puts "tap: #{e.message}"
      1
    end

    def usage(name)
      @ws.err.puts USAGE
      (name.nil? || %w[-h --help help].include?(name)) ? 0 : 2
    end
  end
end
