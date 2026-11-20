# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"
require "rexml/document"

class SiteTest < Minitest::Test
  include TestHelpers

  def files
    attested = tool(name: "demo", desc: "Says <hi> & bye", winget: "GregoireF.demo", publisher: "G",
                    caveats: "Needs git")
    checked = tool(name: "other", verify: "checksum")
    lock = Tap::Lock.new("x", {
      "demo"  => release(tool: attested).with(published: "2026-11-12T23:15:45Z"),
      "other" => release("0.1.0", tool: checked),
    })
    Tap::Targets::Pages.files(catalog([attested, checked, tool(name: "unpublished")], lock))
  end

  def test_pages
    assert_equal %w[.nojekyll demo/index.html feed.xml index.html other/index.html], files.keys.sort
  end

  def test_index_lists_published_tools_and_escapes
    index = files["index.html"]
    assert_includes index, '<a class="name" href="demo/">demo</a>'
    assert_includes index, "Says &lt;hi&gt; &amp; bye"
    refute_includes index, "unpublished"
    assert_includes index, '<span class="badge checksum">SHA-256</span>'
  end

  def test_tool_page_has_every_install_and_verify_command
    page = files["demo/index.html"]
    assert_includes page, "brew install gregoiref/tap/demo"
    assert_includes page, "scoop install gregoiref/demo"
    assert_includes page, "winget install --id GregoireF.demo --exact"
    assert_includes page, "gh attestation verify demo_1.2.3_linux_amd64.tar.gz --repo GregoireF/demo"
    assert_includes page, 'href="../feed.xml"'
    assert_includes files["other/index.html"], "sha256sum --ignore-missing -c checksums.txt"
    refute_includes files["other/index.html"], "winget install"
  end

  def test_feed_is_valid_atom_newest_first
    doc = REXML::Document.new(files["feed.xml"])
    titles = REXML::XPath.match(doc, "//entry/title").map(&:text)
    assert_equal ["demo 1.2.3", "other 0.1.0"], titles
    assert_equal "2026-11-12T23:15:45Z", REXML::XPath.first(doc, "/feed/updated").text
  end
end
