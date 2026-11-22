# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"

# Every relative link of the Markdown files points at a file that exists:
# moving a page cannot leave a broken link behind.
class LinksTest < Minitest::Test
  include TestHelpers

  LINK = /\]\(([^)\s]+)\)/

  def markdown_files
    (Dir[File.join(ROOT, "*.md")] + Dir[File.join(ROOT, "docs/**/*.md")]).reject { |f| f.include?("/templates/") }
  end

  def test_relative_links_resolve
    broken = markdown_files.flat_map do |file|
      text = File.binread(file).force_encoding(Encoding::UTF_8).gsub(/^```.*?^```/m, "")
      text.scan(LINK).flatten.filter_map do |target|
        next if target.match?(%r{\A(?:[a-z]+:|#|<)}) # URLs, anchors, placeholders

        path = target.split("#", 2).first
        next if path.empty?

        resolved = File.expand_path(path, File.dirname(file))
        "#{file.delete_prefix("#{ROOT}/")}: #{target}" unless File.exist?(resolved)
      end
    end
    assert_empty broken, "broken relative links"
  end
end
