# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"
require "json"

# schema/tools.schema.json is for editors; lib/tap/config.rb is what the tap
# enforces. These tests fail as soon as one changes without the other.
class SchemaTest < Minitest::Test
  include TestHelpers

  def schema = JSON.parse(File.binread(File.join(ROOT, "schema/tools.schema.json")))

  def tool_schema = schema.dig("$defs", "tool")

  def test_keys_match_the_config
    assert_equal Tap::Config::KEYS.sort, tool_schema["properties"].keys.sort
    assert_equal Tap::Config::REQUIRED.sort, tool_schema["required"].sort
    assert_equal Tap::Config::TOP_LEVEL.sort, schema["properties"].keys.sort
  end

  def test_enums_and_platforms_match
    assert_equal Tap::VERIFY_LEVELS.sort, tool_schema.dig("properties", "verify", "enum").sort
    assets = tool_schema.dig("properties", "assets")
    assert_equal Tap::PLATFORMS.sort, assets["required"].sort
    assert_equal Tap::PLATFORMS.sort, assets["properties"].keys.sort
  end

  def test_patterns_match
    assert_equal Tap::Config::WINGET_ID.source.delete_prefix("\\A").delete_suffix("\\z"),
                 tool_schema.dig("properties", "winget", "pattern").delete_prefix("^").delete_suffix("$")
  end

  def test_tools_yml_points_editors_at_the_schema
    first = File.binread(File.join(ROOT, "tools.yml")).lines.first
    assert_equal "# yaml-language-server: $schema=schema/tools.schema.json\n", first
  end
end
