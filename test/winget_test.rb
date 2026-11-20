# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"
require "yaml"

class WingetTest < Minitest::Test
  include TestHelpers

  def winget_tool
    tool(binaries: %w[demo dm], winget: "GregoireF.demo", publisher: "Grégoire Favreau",
         desc: "Shows how: the tap works")
  end

  def published_release
    release(tool: winget_tool).with(published: "2026-11-12T23:15:45Z")
  end

  def test_files_follow_the_winget_pkgs_layout
    files = Tap::Targets::Winget.release_files(winget_tool, published_release)
    dir = "winget/manifests/g/GregoireF/demo/1.2.3"
    assert_equal ["#{dir}/GregoireF.demo.yaml", "#{dir}/GregoireF.demo.installer.yaml",
                  "#{dir}/GregoireF.demo.locale.en-US.yaml"], files.keys
  end

  def test_golden
    files = Tap::Targets::Winget.release_files(winget_tool, published_release).values
    assert_golden "demo.winget.yaml", files.join("---\n")
  end

  def test_manifests_are_valid_yaml_with_the_expected_values
    version, installer, locale = Tap::Targets::Winget.release_files(winget_tool, published_release).values.map do |y|
      YAML.safe_load(y, permitted_classes: [Date])
    end

    assert_equal "1.2.3", version["PackageVersion"]
    assert_equal "version", version["ManifestType"]

    assert_equal "portable", installer["NestedInstallerType"]
    assert_equal %w[demo dm], installer["NestedInstallerFiles"].map { |f| f["PortableCommandAlias"] }
    assert_equal "2026-11-12", installer["ReleaseDate"].to_s
    x64 = installer["Installers"].find { |i| i["Architecture"] == "x64" }
    assert_equal Digest::SHA256.hexdigest("windows_amd64").upcase, x64["InstallerSha256"]
    assert x64["InstallerUrl"].end_with?("demo_1.2.3_windows_amd64.zip")

    assert_equal "Grégoire Favreau", locale["Publisher"]
    assert_equal "Shows how: the tap works", locale["ShortDescription"]
    assert_equal "MIT", locale["License"]
  end

  def test_no_release_date_without_a_publication_time
    refute_match(/ReleaseDate/, Tap::Targets::Winget.installer_manifest(winget_tool, release(tool: winget_tool)))
  end

  def test_render_includes_winget_only_for_tools_that_ask
    readme = "#{Tap::Targets::Readme::START}\n#{Tap::Targets::Readme::STOP}\n"
    lock = Tap::Lock.new("x", { "demo" => published_release })
    assert(repository_files([winget_tool], lock, readme:).keys.any? { |k| k.start_with?("winget/") })
    assert(repository_files([tool], lock, readme:).keys.none? { |k| k.start_with?("winget/") })
  end
end
