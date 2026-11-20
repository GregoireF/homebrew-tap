# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"

class ChecksumsTest < Minitest::Test
  SUM = "a" * 64

  def test_parses_text_and_binary_modes
    sums = Tap::Checksums.parse("#{SUM}  ship_1.0.0_linux_amd64.tar.gz\n#{"b" * 64} *kiwa.zip\n\n")
    assert_equal({ "ship_1.0.0_linux_amd64.tar.gz" => SUM, "kiwa.zip" => "b" * 64 }, sums)
  end

  def test_rejects_malformed_lines
    error = assert_raises(Tap::Error) { Tap::Checksums.parse("deadbeef  file.tar.gz\n") }
    assert_match(/unexpected line/, error.message)
  end

  def test_rejects_duplicates
    error = assert_raises(Tap::Error) { Tap::Checksums.parse("#{SUM}  a.zip\n#{SUM}  a.zip\n") }
    assert_match(/listed twice/, error.message)
  end
end
