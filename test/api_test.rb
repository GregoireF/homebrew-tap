# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"
require "json"

# The API output against schema/api.schema.json: every object has exactly
# the keys the schema declares, and the required ones.
class ApiTest < Minitest::Test
  include TestHelpers

  def schema = JSON.parse(File.binread(File.join(ROOT, "schema/api.schema.json")))

  def files
    t = tool(winget: "GregoireF.demo", publisher: "G", formula: "gregoiref-demo")
    releases = {
      "demo"  => release(tool: t).with(published: "2026-11-12T23:15:45Z"),
      "other" => release("0.1.0", tool: tool(name: "other")),
    }
    lock = Tap::Lock.new("x", releases)
    Tap::Targets::Api.files(catalog([t, tool(name: "other")], lock))
  end

  def assert_matches(definition, object)
    defs = schema.fetch("$defs")
    spec = defs.fetch(definition)
    assert_empty object.keys - spec["properties"].keys, "#{definition}: keys the schema does not declare"
    assert_empty spec["required"] - object.keys, "#{definition}: required keys missing"
  end

  def test_paths
    assert_equal %w[api/v1/schema.json api/v1/tools.json api/v1/tools/demo.json api/v1/tools/other.json],
                 files.keys.sort
    assert_equal schema, JSON.parse(files["api/v1/schema.json"])
  end

  def test_index_follows_the_schema
    index = JSON.parse(files["api/v1/tools.json"])
    assert_matches "index", index
    index["tools"].each { |summary| assert_matches "summary", summary }
    assert_equal "https://gregoiref.github.io/homebrew-tap/api/v1/tools/demo.json", index["tools"].first["url"]
  end

  def test_tool_follows_the_schema
    demo = JSON.parse(files["api/v1/tools/demo.json"])
    assert_matches "tool", demo
    assert_equal Tap::PLATFORMS.sort, demo["archives"].keys.sort
    demo["archives"].each_value do |archive|
      assert_matches "archive", archive
      assert_match(/\A[0-9a-f]{64}\z/, archive["sha256"])
    end
    assert_includes schema.dig("$defs", "verified", "enum"), demo["verified"]
    assert_equal "brew install gregoiref/tap/gregoiref-demo", demo["install"]["homebrew"]
    assert_equal "winget install --id GregoireF.demo --exact", demo["install"]["winget"]
    assert_equal "curl -fsSL https://gregoiref.github.io/homebrew-tap/install.sh | sh -s -- demo",
                 demo["install"]["installer"]
    refute JSON.parse(files["api/v1/tools/other.json"])["install"].key?("winget")
  end
end
