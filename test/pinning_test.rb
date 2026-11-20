# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"

class PinningTest < Minitest::Test
  include TestHelpers

  TOOLS = <<~YAML
    tools:
      demo:
        # keep this comment
        repo: GregoireF/demo
        desc: Shows how the tap works
        license: MIT
        binaries: [demo]
        test: [--version]
        verify: checksum
        checksums: checksums.txt
        assets:
          darwin_amd64: demo_{version}_darwin_amd64.tar.gz
          darwin_arm64: demo_{version}_darwin_arm64.tar.gz
          linux_amd64: demo_{version}_linux_amd64.tar.gz
          linux_arm64: demo_{version}_linux_arm64.tar.gz
          windows_amd64: demo_{version}_windows_amd64.zip
          windows_arm64: demo_{version}_windows_arm64.zip
      other:
        repo: GregoireF/other
  YAML

  def test_pin_edit_sets_replaces_and_removes
    pinned = Tap::Commands::PinEdit.set(TOOLS, "demo", "1.0.0")
    assert_includes pinned, "  demo:\n    pin: \"1.0.0\"\n    # keep this comment\n"
    again = Tap::Commands::PinEdit.set(pinned, "demo", "0.9.0")
    assert_equal 1, again.scan("pin:").size
    assert_includes again, "pin: \"0.9.0\""
    assert_equal TOOLS, Tap::Commands::PinEdit.unset(again, "demo")
    assert_raises(Tap::Error) { Tap::Commands::PinEdit.unset(TOOLS, "demo") }
    assert_raises(Tap::Error) { Tap::Commands::PinEdit.set(TOOLS, "missing", "1.0.0") }
  end

  def published(version)
    t = tool(verify: "checksum")
    files = Tap::PLATFORMS.to_h { |p| [t.asset_name(p, version), "#{version} #{p}"] }
    sums = files.map { |n, b| "#{Digest::SHA256.hexdigest(b)}  #{n}\n" }.join
    { tag: "v#{version}", files: files.merge("checksums.txt" => sums) }
  end

  def test_sync_serves_the_pinned_release_even_when_older
    t = tool(verify: "checksum", pin: "1.0.0")
    lock = Tap::Lock.new("x", { "demo" => release("2.0.0", tool: t) })
    github = FakeGitHub.new({ "GregoireF/demo" => published("2.0.0") },
                            older: { "GregoireF/demo" => [published("1.0.0")] })
    updates = Tap::Sync.new(lock:, github:, verifier: FakeVerifier.new, log: StringIO.new).run([t])
    assert_equal [Tap::Sync::Update.new(tool: "demo", from: "2.0.0", to: "1.0.0")], updates
    assert_equal "v1.0.0", lock["demo"].tag
    msg = Tap::Commands::Sync.commit_message(updates)
    assert msg.start_with?("⏪ revert(demo): back to 1.0.0\n")
  end

  def test_sync_fails_on_a_missing_pinned_release
    github = FakeGitHub.new({ "GregoireF/demo" => published("2.0.0") })
    error = assert_raises(Tap::Error) do
      Tap::Sync.new(lock: Tap::Lock.new("x", {}), github:, verifier: FakeVerifier.new,
                    log: StringIO.new).run([tool(pin: "1.5.0")])
    end
    assert_match(/no release for the pinned version 1.5.0/, error.message)
  end

  def cli_root
    Dir.mktmpdir do |root|
      File.binwrite(File.join(root, "tools.yml"), TOOLS.sub("  other:\n    repo: GregoireF/other\n", ""))
      lock = Tap::Lock.new(File.join(root, "tools.lock.json"), { "demo" => release("2.0.0") })
      lock.save
      yield root
    end
  end

  def test_rollback_and_unpin_commands
    github = FakeGitHub.new({ "GregoireF/demo" => published("2.0.0") },
                            older: { "GregoireF/demo" => [published("1.9.0"), published("1.10.0"),
                                                          { tag: "nightly", files: {} }] })
    cli_root do |root|
      err = StringIO.new
      assert_equal 0, Tap::CLI.new(root:, out: StringIO.new, err:, github:).run(%w[rollback demo])
      assert_includes err.string, "pinned demo to 1.10.0 (was 2.0.0)"
      assert_equal "1.10.0", Tap::Config.load(File.join(root, "tools.yml")).first.pin

      assert_equal 0, Tap::CLI.new(root:, out: StringIO.new, err: StringIO.new).run(%w[unpin demo])
      assert_nil Tap::Config.load(File.join(root, "tools.yml")).first.pin
    end
  end

  def test_rollback_errors
    github = FakeGitHub.new({ "GregoireF/demo" => published("2.0.0") })
    cli_root do |root|
      err = StringIO.new
      assert_equal 1, Tap::CLI.new(root:, out: StringIO.new, err:, github:).run(%w[rollback demo])
      assert_includes err.string, "no stable release older than 2.0.0"

      err = StringIO.new
      assert_equal 1, Tap::CLI.new(root:, out: StringIO.new, err:, github:).run(%w[rollback nope])
      assert_includes err.string, "no tool named nope"

      File.delete(File.join(root, "tools.lock.json"))
      err = StringIO.new
      assert_equal 1, Tap::CLI.new(root:, out: StringIO.new, err:, github:).run(%w[rollback demo])
      assert_includes err.string, "never published"
    end
  end

  def test_config_requires_a_quoted_version
    entry = YAML.safe_load(TOOLS)["tools"]["demo"]
    assert_equal "1.2.3", Tap::Config.build("demo", entry.merge("pin" => "1.2.3"), "tools.yml").pin
    error = assert_raises(Tap::Error) { Tap::Config.build("demo", entry.merge("pin" => 1.2), "tools.yml") }
    assert_match(/pin: expected a quoted version/, error.message)
  end

  def test_health_lists_pinned_tools
    t = tool(pin: "1.0.0")
    r = release("1.0.0", tool: t)
    lock = Tap::Lock.new("x", { "demo" => r })
    attested = Tap::PLATFORMS.map { |p| r.sha256(p) }
    findings = Tap::Health.new(github: FakeGitHub.new({}, attested:)).run([t], lock)
    assert_equal ["`demo` is pinned to 1.0.0: run `bin/tap unpin demo` once a fixed release is out"], findings
  end
end
