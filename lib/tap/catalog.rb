# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

module Tap
  # What every target renders from: the tools of tools.yml and the releases
  # the lock serves for them. `readme` is the hand-written README the readme
  # target fills in.
  Catalog = Data.define(:tools, :lock, :readme) do
    # [tool, release] for every tool that has a published release, in
    # tools.yml order.
    define_method(:served) do
      tools.filter_map { |tool| (release = lock[tool.name]) && [tool, release] }
    end
  end.freeze
end
