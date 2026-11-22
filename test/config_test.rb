# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"

class ConfigTest < Minitest::Test
  include TestHelpers

  def entry(**overrides)
    {
      "repo" => "GregoireF/demo", "desc" => "Demonstrates the tap", "license" => "MIT",
      "binaries" => ["demo"], "test" => ["--version"], "verify" => "attestation",
      "checksums" => "checksums.txt", "assets" => Tap::PLATFORMS.to_h { |p| [p, "demo_#{p}.tar.gz"] }
    }.merge(overrides.transform_keys(&:to_s))
  end

  def build(name = "demo", **overrides) = Tap::Config.build(name, entry(**overrides), "tools.yml")

  def assert_config_error(pattern, &)
    error = assert_raises(Tap::Error, &)
    assert_match pattern, error.message
  end

  def test_repository_tools_yml_is_valid
    tools = Tap::Config.load(File.join(ROOT, "tools.yml"))
    assert_equal %w[addlicense kiwa ship], tools.map(&:name)
  end

  def test_builds_a_tool
    tool = build(caveats: "Read the docs")
    assert_equal "GregoireF/demo", tool.repo
    assert_equal "Read the docs", tool.caveats
    assert_equal "https://github.com/GregoireF/demo", tool.homepage
  end

  def test_class_name_follows_homebrew
    assert_equal "Ship", tool(name: "ship").class_name
    assert_equal "AddLicenseCli", tool(name: "add-license-cli").class_name
  end

  def test_asset_name_substitutes_the_version
    assert_equal "demo_1.2.3_linux_amd64.tar.gz", tool.asset_name("linux_amd64", "1.2.3")
  end

  def test_rejects_unknown_and_missing_keys
    assert_config_error(/unknown keys bottle/) { build(bottle: true) }
    assert_config_error(/missing keys repo/) { Tap::Config.build("demo", entry.except("repo"), "tools.yml") }
  end

  def test_rejects_bad_names_and_repos
    assert_config_error(/name must match/) { build("Demo") }
    assert_config_error(%r{expected owner/name}) { build(repo: "demo") }
  end

  def test_applies_the_brew_audit_desc_rules
    assert_config_error(/ends with a period/) { build(desc: "Does things.") }
    assert_config_error(/starts with an article/) { build(desc: "A tool") }
    assert_config_error(/starts with the tool's name/) { build(desc: "Demo does things") }
    assert_config_error(/longer than 80/) { build(desc: "x" * 81) }
  end

  def test_rejects_unknown_verify_levels
    assert_config_error(/verify: expected one of/) { build(verify: "trust-me") }
  end

  def test_requires_every_platform
    assets = entry["assets"].except("windows_arm64")
    assert_config_error(/assets: missing windows_arm64/) { build(assets:) }
    assert_config_error(/unknown platforms freebsd_amd64/) do
      build(assets: entry["assets"].merge("freebsd_amd64" => "x"))
    end
  end

  def test_optional_completions_and_winget
    tool = Tap::Config.build("demo", entry(completions: ["completion"], winget: "GregoireF.demo"), "tools.yml",
                             publisher: "Grégoire Favreau")
    assert_equal ["completion"], tool.completions
    assert_equal "GregoireF.demo", tool.winget
    assert_equal "Grégoire Favreau", tool.publisher

    assert_config_error(/completions: empty/) { build(completions: []) }
    assert_config_error(/completions: expected a list/) { build(completions: "completion") }
    assert_config_error(/winget: expected a package identifier/) { build(winget: "demo") }
    assert_config_error(/winget: needs a top-level `publisher`/) { build(winget: "GregoireF.demo") }
  end

  def test_optional_formula_and_conflicts
    tool = build(formula: "gregoiref-demo", conflicts: ["demo"])
    assert_equal "gregoiref-demo", tool.formula_name
    assert_equal ["demo"], tool.conflicts
    assert_equal "demo", build.formula_name
    assert_empty build.conflicts

    assert_config_error(/formula: must match/) { build(formula: "Demo Tool") }
    assert_config_error(/conflicts: not formula names: Bad/) { build(conflicts: ["Bad"]) }
  end

  def test_optional_nested
    assert build(nested: true).nested
    refute build.nested
    assert_config_error(/nested: expected true or false/) { build(nested: "yes") }
  end

  def test_unknown_top_level_keys
    Dir.mktmpdir do |dir|
      path = File.join(dir, "tools.yml")
      File.binwrite(path, "tools: {}\nbottles: true\n")
      assert_config_error(/unknown top-level keys bottles/) { Tap::Config.load(path) }
    end
  end

  def test_requires_lists_of_strings
    assert_config_error(/binaries: expected a list/) { build(binaries: "demo") }
    assert_config_error(/binaries: empty/) { build(binaries: []) }
  end
end
