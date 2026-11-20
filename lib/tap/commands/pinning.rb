# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "rubygems"

module Tap
  module Commands
    # Edits `pin:` lines of tools.yml as text, so its comments stay.
    module PinEdit
      module_function

      # The [first, last] line indexes of `  <name>:`'s block under tools:.
      def block(lines, name)
        start = lines.index("  #{name}:\n") || raise(Error, "tools.yml has no tool named #{name}")
        stop = ((start + 1)...lines.size).find { |i| lines[i].match?(/\A {0,2}\S/) } || lines.size
        [start, stop - 1]
      end

      def set(text, name, version)
        lines = text.lines
        first, last = block(lines, name)
        line = "    pin: \"#{version}\"\n"
        if (i = (first..last).find { |j| lines[j].start_with?("    pin:") })
          lines[i] = line
        else
          lines.insert(first + 1, line)
        end
        lines.join
      end

      def unset(text, name)
        lines = text.lines
        first, last = block(lines, name)
        i = (first..last).find { |j| lines[j].start_with?("    pin:") } || raise(Error, "#{name} is not pinned")
        lines.delete_at(i)
        lines.join
      end
    end

    # `rollback TOOL`: pins TOOL to the stable release before the one the lock
    # serves. The next sync installs, tests and publishes it like any version.
    class Rollback < Base
      def call(args)
        name = arg(args, 0, "rollback TOOL")
        tool = ws.tools.find { |t| t.name == name } || raise(Error, "tools.yml has no tool named #{name}")
        current = ws.lock[name] || raise(Error, "#{name} was never published, nothing to roll back")

        older = ws.github.stable_tags(tool.repo).filter_map do |tag|
          version = tag.delete_prefix("v")
          next unless version.match?(Config::VERSION)

          version if Gem::Version.new(version) < Gem::Version.new(current.version)
        end
        previous = older.max_by { |v| Gem::Version.new(v) } ||
                   raise(Error, "#{name} has no stable release older than #{current.version}")

        File.binwrite(ws.path("tools.yml"), PinEdit.set(ws.read("tools.yml"), name, previous))
        ws.err.puts "pinned #{name} to #{previous} (was #{current.version}); bin/tap unpin #{name} undoes it"
        0
      end
    end

    # `unpin TOOL`: back to the latest stable release at the next sync.
    class Unpin < Base
      def call(args)
        name = arg(args, 0, "unpin TOOL")
        File.binwrite(ws.path("tools.yml"), PinEdit.unset(ws.read("tools.yml"), name))
        ws.err.puts "unpinned #{name}"
        0
      end
    end
  end
end
