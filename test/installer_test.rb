# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"

# The generated install.sh; test/installer.sh runs it for real in CI.
class InstallerTest < Minitest::Test
  include TestHelpers

  def script(tools = [tool])
    lock = Tap::Lock.new("x", tools.to_h { |t| [t.name, release(tool: t)] })
    Tap::Targets::Installer.files(catalog(tools, lock)).fetch("install.sh")
  end

  def test_one_case_per_unix_platform_with_url_and_sha
    out = script
    Tap::Targets::Installer::UNIX.each do |platform|
      assert_includes out, "    demo/#{platform})\n"
      assert_includes out, "      sha256=#{Digest::SHA256.hexdigest(platform)}\n"
    end
    refute_includes out, "windows"
    assert_includes out, "url='https://github.com/GregoireF/demo/releases/download/v1.2.3/demo_1.2.3_linux_arm64.tar.gz'"
    assert_includes out, "# Tools: demo 1.2.3\n"
  end

  def test_shell_quoting
    assert_equal "'it'\\''s'", Tap::Targets::Installer.sh("it's")
    out = script([tool(binaries: %w[demo dm])])
    assert_includes out, "binaries='demo dm'"
  end

  def test_verification_level_is_carried
    assert_includes script([tool(verify: "checksum")]), "verified=checksum"
    assert_includes script, "verified=attestation"
  end
end
