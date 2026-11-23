# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

module Tap
  module Commands
    # `render`: writes every repository target's files and deletes the files
    # they no longer produce (an old WinGet version, a removed tool).
    # `check`: the same comparison, without writing; exit 1 on any drift.
    class Render < Base
      def call(_args)
        files = Targets.files(Targets.repository, ws.catalog)
        files.each { |rel, content| ws.write(rel, content) }
        (ws.existing(Targets.repository) - files.keys).each do |rel|
          File.delete(ws.path(rel))
          ws.err.puts "removed #{rel}"
        end
        ws.remove_empty_dirs("winget")
        0
      end
    end

    # See Render.
    class Check < Base
      def call(_args)
        files = Targets.files(Targets.repository, ws.catalog)
        drift = files.reject { |rel, content| ws.read(rel) == content }.keys
        stray = ws.existing(Targets.repository) - files.keys
        drift.each { |rel| ws.err.puts "tap: #{rel} is out of date, run bin/tap render" }
        stray.each { |rel| ws.err.puts "tap: #{rel} is not generated from tools.yml, run bin/tap render" }
        clean = drift.empty? && stray.empty?
        clean ? 0 : 1
      end
    end
  end
end
