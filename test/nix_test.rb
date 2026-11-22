# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"

# flake.nix; install-test.yml builds and runs it with Nix itself.
class NixTest < Minitest::Test
  include TestHelpers

  def flake(tools = [tool])
    lock = Tap::Lock.new("x", tools.to_h { |t| [t.name, release(tool: t)] })
    Tap::Targets::Nix.files(catalog(tools, lock)).fetch("flake.nix")
  end

  # kiwa 0.1.0 x86_64-linux: the pair Nix's fetchurl accepted in install-test.
  def test_sri_hash
    hex = "6a30221a00308ffe78372a2f761f64b9c8d14bc5ea611ca792fff1f486553e7c"
    assert_equal "sha256-ajAiGgAwj/54Nyovdh9kucjRS8XqYRynkv/x9IZVPnw=", Tap::Targets::Nix.sri(hex)
  end

  def test_string_escaping
    assert_equal '"a \\"b\\" \\${c} \\\\ d"', Tap::Targets::Nix.string('a "b" ${c} \\ d')
  end

  def test_one_archive_per_unix_platform
    out = flake
    Tap::Targets::Nix::UNIX.each do |platform|
      assert_includes out, "            #{platform} = {\n"
      assert_includes out, "hash = \"#{Tap::Targets::Nix.sri(Digest::SHA256.hexdigest(platform))}\";"
    end
    refute_includes out, "windows"
    assert_includes out, "        demo = {\n"
    assert_includes out, 'binaries = [ "demo" ];'
  end

  def test_golden
    assert_golden "flake.nix", flake([tool(binaries: %w[demo dm])])
  end

  def test_nothing_without_a_served_tool
    assert_empty Tap::Targets::Nix.files(catalog([tool], Tap::Lock.new("x", {})))
  end
end
