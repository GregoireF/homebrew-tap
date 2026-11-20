# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"
require "time"

class HealthTest < Minitest::Test
  include TestHelpers

  NOW = Time.utc(2026, 11, 20).freeze

  def all_digests(release) = Tap::PLATFORMS.map { |p| release.sha256(p) }

  def findings(tools, releases, attested:)
    lock = Tap::Lock.new("x", releases)
    Tap::Health.new(github: FakeGitHub.new({}, attested:), now: NOW).run(tools, lock)
  end

  def test_healthy
    r = release.with(published: "2026-10-01T00:00:00Z")
    assert_empty findings([tool], { "demo" => r }, attested: all_digests(r))
    assert_equal "Everything the tap serves is healthy.\n", Tap::Health.report([])
  end

  def test_never_published
    assert_match(/never published/, findings([tool], {}, attested: []).first)
  end

  def test_stale
    r = release.with(published: "2025-06-01T00:00:00Z")
    assert_match(/more than 365 days ago/, findings([tool], { "demo" => r }, attested: all_digests(r)).first)
  end

  def test_lost_provenance
    r = release
    found = findings([tool], { "demo" => r }, attested: all_digests(r) - [r.sha256("darwin_arm64")])
    assert_equal ["`demo` 1.2.3: no provenance any more for darwin_arm64"], found
  end

  def test_suggests_raising_a_checksum_tool
    t = tool(verify: "checksum")
    r = release(tool: t)
    assert_match(/set `verify: attestation`/, findings([t], { "demo" => r }, attested: all_digests(r)).first)
    assert_empty findings([t], { "demo" => r }, attested: [])
  end

  def test_report_lists_findings
    assert_equal "- a\n- b\n", Tap::Health.report(%w[a b])
  end
end
