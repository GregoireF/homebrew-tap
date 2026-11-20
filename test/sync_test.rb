# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"

class SyncTest < Minitest::Test
  include TestHelpers

  # A release of `tool` whose archives contain their own names.
  def published(version, tool: self.tool, tamper: nil, drop: nil)
    files = Tap::PLATFORMS.to_h { |p| [tool.asset_name(p, version), "bytes of #{p}"] }
    sums = files.map { |name, bytes| "#{Digest::SHA256.hexdigest(bytes)}  #{name}" }.join("\n")
    files[tamper] = "tampered" if tamper
    files.delete(drop) if drop
    files[tool.checksums] = "#{sums}\n"
    { tag: "v#{version}", files: }
  end

  def run_sync(lock, releases, tools: [tool], verifier: FakeVerifier.new)
    github = FakeGitHub.new(releases)
    updates = Tap::Sync.new(lock:, github:, verifier:, log: StringIO.new).run(tools)
    [updates, github, verifier]
  end

  def test_records_a_new_tool
    lock = Tap::Lock.new("x", {})
    updates, github, verifier = run_sync(lock, { "GregoireF/demo" => published("1.0.0") })

    assert_equal [Tap::Sync::Update.new(tool: "demo", from: nil, to: "1.0.0")], updates
    assert_equal 6, github.downloads.size
    assert_equal 6, verifier.checked.size
    assert_equal Digest::SHA256.hexdigest("bytes of linux_arm64"), lock["demo"].sha256("linux_arm64")
    assert_equal "demo_1.0.0_linux_arm64.tar.gz", lock["demo"].assets["linux_arm64"]["name"]
  end

  def test_skips_a_tool_already_up_to_date
    lock = Tap::Lock.new("x", {})
    run_sync(lock, { "GregoireF/demo" => published("1.0.0") })
    updates, github, = run_sync(lock, { "GregoireF/demo" => published("1.0.0") })
    assert_empty updates
    assert_empty github.downloads
  end

  def test_upgrades
    lock = Tap::Lock.new("x", {})
    run_sync(lock, { "GregoireF/demo" => published("1.0.0") })
    updates, = run_sync(lock, { "GregoireF/demo" => published("1.1.0") })
    assert_equal [Tap::Sync::Update.new(tool: "demo", from: "1.0.0", to: "1.1.0")], updates
  end

  def test_refuses_to_downgrade
    lock = Tap::Lock.new("x", {})
    run_sync(lock, { "GregoireF/demo" => published("2.0.0") })
    error = assert_raises(Tap::Error) { run_sync(lock, { "GregoireF/demo" => published("1.9.0") }) }
    assert_match(/refusing to downgrade/, error.message)
    assert_equal "2.0.0", lock["demo"].version
  end

  def test_rejects_an_archive_that_does_not_match_its_checksum
    lock = Tap::Lock.new("x", {})
    release = published("1.0.0", tamper: "demo_1.0.0_darwin_arm64.tar.gz")
    error = assert_raises(Tap::Error) { run_sync(lock, { "GregoireF/demo" => release }) }
    assert_match(/darwin_arm64.tar.gz has SHA-256/, error.message)
    assert_nil lock["demo"]
  end

  def test_rejects_an_archive_without_provenance
    lock = Tap::Lock.new("x", {})
    verifier = FakeVerifier.new(reject: ["demo_1.0.0_windows_amd64.zip"])
    error = assert_raises(Tap::Error) do
      run_sync(lock, { "GregoireF/demo" => published("1.0.0") }, verifier:)
    end
    assert_match(/no valid provenance/, error.message)
    assert_nil lock["demo"]
  end

  def test_checksum_level_skips_provenance
    t = tool(verify: "checksum")
    _, _, verifier = run_sync(Tap::Lock.new("x", {}), { "GregoireF/demo" => published("1.0.0", tool: t) }, tools: [t])
    assert_empty verifier.checked
  end

  def test_raising_the_verify_level_rechecks_the_same_release
    lock = Tap::Lock.new("x", {})
    t = tool(verify: "checksum")
    run_sync(lock, { "GregoireF/demo" => published("1.0.0", tool: t) }, tools: [t])
    updates, _, verifier = run_sync(lock, { "GregoireF/demo" => published("1.0.0") })
    assert_equal 1, updates.size
    assert_equal 6, verifier.checked.size
    assert_equal "attestation", lock["demo"].verified
  end

  def test_missing_archive
    release = published("1.0.0", drop: "demo_1.0.0_linux_amd64.tar.gz")
    error = assert_raises(Tap::Error) { run_sync(Tap::Lock.new("x", {}), { "GregoireF/demo" => release }) }
    assert_match(/release has no demo_1.0.0_linux_amd64.tar.gz/, error.message)
  end

  def test_tag_that_is_not_a_version
    error = assert_raises(Tap::Error) do
      run_sync(Tap::Lock.new("x", {}), { "GregoireF/demo" => published("1.0.0").merge(tag: "latest") })
    end
    assert_match(/is not a version/, error.message)
  end

  def test_tool_without_release
    updates, = run_sync(Tap::Lock.new("x", {}), {})
    assert_empty updates
  end
end
