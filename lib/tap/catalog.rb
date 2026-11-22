# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

module Tap
  # What every target renders from: the tools of tools.yml, the releases the
  # lock serves for them, the hand-written README the readme target fills in,
  # and `status`, facts the site shows that the repository does not hold
  # (`install_tests`: the last nightly install test on main, passing or
  # failing), passed in by the workflow.
  Catalog = Data.define(:tools, :lock, :readme, :status) do
    # [tool, release] for every tool that has a published release, in
    # tools.yml order.
    define_method(:served) do
      tools.filter_map { |tool| (release = lock[tool.name]) && [tool, release] }
    end
  end.freeze
end
