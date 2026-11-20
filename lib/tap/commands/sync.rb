# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

module Tap
  module Commands
    # `sync`: brings the lock up to date with the latest verified releases,
    # renders, and hands `changed`, `tools` and `message` to the workflow.
    class Sync < Base
      HEADER_MAX = 72

      def self.commit_message(updates)
        header =
          if updates.size == 1
            single_header(updates.first)
          else
            list = updates.map { |u| "#{u.tool} #{u.to}" }.join(", ")
            candidate = "⬆️ build(tools): #{list}"
            (candidate.length <= HEADER_MAX) ? candidate : "⬆️ build(tools): #{updates.size} updates"
          end
        body = updates.map { |u| "- #{u.tool}: #{u.from || "new"} -> #{u.to}" }.join("\n")
        "#{header}\n\n#{body}\n"
      end

      def self.single_header(update)
        if update.from.nil?
          "✨ feat(#{update.tool}): add #{update.to}"
        elsif Gem::Version.new(update.to) < Gem::Version.new(update.from)
          "⏪ revert(#{update.tool}): back to #{update.to}"
        else
          "⬆️ build(#{update.tool}): #{update.to}"
        end
      end

      def call(_args)
        updates = Tap::Sync.new(lock: ws.lock, github: ws.github, verifier: ws.verifier, log: ws.err).run(ws.tools)
        if updates.empty?
          ws.out.puts "everything up to date"
          ws.output(changed: "false")
          return 0
        end

        ws.lock.save
        Render.new(ws).call([])
        message = self.class.commit_message(updates)
        ws.out.puts message
        ws.output(changed: "true", tools: updates.map(&:tool).join(" "), message:)
        0
      end
    end
  end
end
