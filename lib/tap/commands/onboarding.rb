# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

module Tap
  module Commands
    # `add OWNER/REPO`: appends a tools.yml entry inferred from the latest
    # release (comments in the file are kept).
    class Add < Base
      def call(args)
        repo = arg(args, 0, "add OWNER/REPO")
        tools = ws.tools
        raise Error, "#{repo} is already in tools.yml" if tools.any? { |t| t.repo == repo }

        name, entry = Onboard.new(github: ws.github, publisher: ws.publisher).entry(repo)
        raise Error, "a tool named #{name} is already in tools.yml" if tools.any? { |t| t.name == name }

        current = ws.read("tools.yml").chomp
        addition = Onboard.yaml(name, entry)
        File.binwrite(ws.path("tools.yml"), "#{current}\n#{addition}")
        ws.err.puts "added #{name} (#{repo}) to tools.yml"
        0
      end
    end

    # `discover [--add]`: repositories with the gregoiref-tap topic that
    # tools.yml does not know. With --add, each is added when its entry can be
    # inferred; one that cannot is reported and skipped, so sync goes on.
    class Discover < Base
      OWNER = "GregoireF"
      TOPIC = "gregoiref-tap"

      def call(args)
        known = ws.tools.map(&:repo)
        (ws.github.repos_with_topic(OWNER, TOPIC) - known).each do |repo|
          next ws.out.puts(repo) unless args.include?("--add")

          begin
            Add.new(ws).call([repo])
          rescue Error => e
            ws.err.puts "tap: skipped #{repo}: #{e.message}"
          end
        end
        0
      end
    end
  end
end
