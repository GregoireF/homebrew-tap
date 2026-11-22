# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"
require "json"

# The generated reference pages; `bin/tap check` keeps the committed copies
# in step with their sources.
class DocsTest < Minitest::Test
  include TestHelpers

  def files = Tap::Targets::Docs.files(catalog([], Tap::Lock.new("x", {})))

  def test_every_tools_yml_key_is_documented
    page = files.fetch("docs/reference/tools-yml.md")
    Tap::Config::KEYS.each { |key| assert_includes page, "| `#{key}` |" }
    assert_includes page, "| `binaries` | yes | list of strings |"
    assert_includes page, "Formula/&lt;formula&gt;.rb"
  end

  def test_every_api_field_is_documented
    page = files.fetch("docs/reference/api.md")
    schema = JSON.parse(File.binread(File.join(ROOT, "schema/api.schema.json")))
    %w[index summary tool archive].each do |name|
      schema.dig("$defs", name, "properties").each_key { |key| assert_includes page, "| `#{key}` |" }
    end
    assert_includes page, "| `verified` | yes | `verified` |"
  end

  def test_cli_page_is_the_usage
    assert_includes files.fetch("docs/reference/cli.md"), Tap::CLI::USAGE.lines.first
  end

  def test_type_labels
    assert_equal "`checksum` or `attestation`", Tap::Targets::Docs.type("enum" => %w[checksum attestation])
    assert_equal "string or null", Tap::Targets::Docs.type("type" => %w[string null])
  end
end
