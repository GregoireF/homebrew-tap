# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"

class LockTest < Minitest::Test
  include TestHelpers

  def test_round_trip_keeps_the_publication_time_and_sorts_tools
    Dir.mktmpdir do |dir|
      path = File.join(dir, "tools.lock.json")
      lock = Tap::Lock.new(path, {})
      lock["zeta"] = release("2.0.0")
      lock["alpha"] = release("1.0.0").with(published: "2026-11-12T23:15:45Z")
      lock.save

      text = File.binread(path)
      assert text.index('"alpha"') < text.index('"zeta"')
      loaded = Tap::Lock.load(path)
      assert_equal "2026-11-12T23:15:45Z", loaded["alpha"].published
      assert_nil loaded["zeta"].published
      refute_includes text[text.index('"zeta"')..], "published"
      assert_equal %w[alpha zeta], loaded.names.sort
    end
  end

  def test_missing_file_is_an_empty_lock
    assert_empty Tap::Lock.load("does/not/exist.json").names
  end
end
