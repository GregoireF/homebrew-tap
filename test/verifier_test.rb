# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"
require "rbconfig"

class VerifierTest < Minitest::Test
  # Stands in for gh: succeeds when the archive's name contains "good",
  # and records its arguments.
  FAKE_GH = <<~RUBY
    File.write(ENV.fetch("FAKE_GH_LOG"), ARGV.join(" "))
    exit(ARGV[2].include?("good") ? 0 : 1)
  RUBY

  def with_fake_gh
    Dir.mktmpdir do |dir|
      script = File.join(dir, "gh.rb")
      File.write(script, FAKE_GH)
      log = File.join(dir, "log")
      ENV["FAKE_GH_LOG"] = log
      yield Tap::Verifier.new(command: [RbConfig.ruby, script]), log
    ensure
      ENV.delete("FAKE_GH_LOG")
    end
  end

  def test_accepts_a_verified_archive
    with_fake_gh do |verifier, log|
      assert_nil verifier.check_attestation("/tmp/good.tar.gz", "GregoireF/kiwa")
      assert_equal "attestation verify /tmp/good.tar.gz --repo GregoireF/kiwa", File.read(log)
    end
  end

  def test_rejects_an_unverified_archive
    with_fake_gh do |verifier, _|
      error = assert_raises(Tap::Error) { verifier.check_attestation("/tmp/bad.tar.gz", "GregoireF/kiwa") }
      assert_match(%r{bad.tar.gz: no valid provenance from GregoireF/kiwa}, error.message)
    end
  end
end
