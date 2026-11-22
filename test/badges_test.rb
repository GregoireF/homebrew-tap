# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"
require "json"

class BadgesTest < Minitest::Test
  include TestHelpers

  def badges(status: {}, verify: "attestation")
    t = tool(verify:)
    files = Tap::Targets::Badges.files(catalog([t], Tap::Lock.new("x", { "demo" => release(tool: t) }), status:))
    files.transform_values { |json| JSON.parse(json) }
  end

  def test_one_endpoint_per_kind
    assert_equal %w[homebrew install-tests provenance scoop].map { |k| "badges/demo/#{k}.json" },
                 badges.keys.sort
    assert_equal({ "schemaVersion" => 1, "label" => "homebrew", "message" => "1.2.3", "color" => "orange" },
                 badges["badges/demo/homebrew.json"])
  end

  def test_provenance
    assert_equal "SLSA verified", badges["badges/demo/provenance.json"]["message"]
    assert_equal "SHA-256 only", badges(verify: "checksum")["badges/demo/provenance.json"]["message"]
  end

  def test_install_tests
    assert_equal "unknown", badges["badges/demo/install-tests.json"]["message"]
    assert_equal "6 platforms passing",
                 badges(status: { "install_tests" => "passing" })["badges/demo/install-tests.json"]["message"]
    assert_equal "red", badges(status: { "install_tests" => "failing" })["badges/demo/install-tests.json"]["color"]
  end

  def test_markdown_snippet
    md = Tap::Targets::Badges.markdown(tool)
    assert_equal 4, md.lines.size
    assert_includes md, "https://img.shields.io/endpoint?url=https://gregoiref.github.io/homebrew-tap/badges/demo/scoop.json"
  end

  def test_site_command_passes_the_install_test_result
    Dir.mktmpdir do |root|
      %w[tools.yml tools.lock.json].each { |f| FileUtils.cp(File.join(ROOT, f), root) }
      site = File.join(root, "_site")
      cli = Tap::CLI.new(root:, out: StringIO.new, err: StringIO.new)
      assert_equal 0, cli.run(["site", site, "--install-tests", "passing"])
      assert_includes File.binread(File.join(site, "badges/kiwa/install-tests.json")), "passing"
      assert File.exist?(File.join(site, "api/v1/tools/kiwa.json"))

      err = StringIO.new
      assert_equal 1, Tap::CLI.new(root:, out: StringIO.new, err:).run(["site", site, "--install-tests", "maybe"])
      assert_includes err.string, "expected passing or failing"
    end
  end
end
