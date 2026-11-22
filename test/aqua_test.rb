# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"
require "yaml"

# aqua/registry.yaml; test/aqua.sh installs from it with aqua itself.
class AquaTest < Minitest::Test
  include TestHelpers

  def registry(tools)
    YAML.safe_load(Tap::Targets::Aqua.files(catalog(tools, Tap::Lock.new("x", {}))).fetch("aqua/registry.yaml"))
  end

  def test_one_github_release_package_per_tool
    pkg = registry([tool(binaries: %w[demo dm])])["packages"].first
    assert_equal %w[github_release GregoireF demo], pkg.values_at("type", "repo_owner", "repo_name")
    assert_equal "demo_{{trimV .Version}}_linux_amd64.tar.gz", pkg["asset"]
    assert_equal "tar.gz", pkg["format"]
    assert_equal({ "type" => "github_release", "asset" => "checksums.txt", "algorithm" => "sha256" }, pkg["checksum"])
    assert_equal [{ "name" => "demo", "src" => "demo" }, { "name" => "dm", "src" => "dm" }], pkg["files"]
    assert_equal 5, pkg["overrides"].size
    windows = pkg["overrides"].find { |o| o["goos"] == "windows" && o["goarch"] == "arm64" }
    assert_equal "zip", windows["format"]
    assert_equal "demo.exe", windows["files"].first["src"]
  end

  def test_nested_archives
    pkg = registry([tool(nested: true)])["packages"].first
    assert_equal "{{.AssetWithoutExt}}/demo", pkg["files"].first["src"]
    windows = pkg["overrides"].find { |o| o["goos"] == "windows" }
    assert_equal "demo.exe", windows["files"].first["src"]
  end

  def test_formats_and_errors
    assets = Tap::PLATFORMS.to_h { |p| [p, "demo_#{p}.tar.xz"] }
    assert_equal "tar.xz", registry([tool(assets:)])["packages"].first["format"]
    assert_raises(Tap::Error) { registry([tool(assets: assets.merge("linux_amd64" => "demo.7z"))]) }
    assert_empty Tap::Targets::Aqua.files(catalog([], Tap::Lock.new("x", {})))
  end
end
