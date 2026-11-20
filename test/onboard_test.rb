# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"
require "yaml"

class OnboardTest < Minitest::Test
  include TestHelpers

  REPO = "GregoireF/widget"

  # A GoReleaser-style release, plus distractors the inference must skip.
  def goreleaser_files(version = "2.1.0")
    names = Tap::PLATFORMS.map do |p|
      os, arch = p.split("_")
      "widget_#{version}_#{os}_#{arch}.#{(os == "windows") ? "zip" : "tar.gz"}"
    end
    files = names.to_h { |n| [n, "bytes #{n}"] }
    files["widget_#{version}_linux_amd64.tar.gz.sbom.json"] = "{}"
    files["widget_#{version}_linux_amd64-musl.tar.gz"] = "musl"
    files["checksums.txt"] = files.map { |n, b| "#{Digest::SHA256.hexdigest(b)}  #{n}\n" }.join
    files
  end

  def github(files: goreleaser_files, description: "A tiny widget for your terminal.", license: "MIT",
             attested: true)
    sha = Digest::SHA256.hexdigest("bytes widget_2.1.0_linux_amd64.tar.gz")
    FakeGitHub.new({ REPO => { tag: "v2.1.0", files: } },
                   repos:    { REPO => { description:, license:, topics: ["gregoiref-tap"] } },
                   attested: attested ? [sha] : [])
  end

  def entry(**options)
    publisher = options.delete(:publisher)
    Tap::Onboard.new(github: github(**options), publisher:).entry(REPO)
  end

  def test_infers_a_goreleaser_release
    name, entry = entry(publisher: "Grégoire Favreau")
    assert_equal "widget", name
    assert_equal "Tiny widget for your terminal", entry["desc"]
    assert_equal "MIT", entry["license"]
    assert_equal ["widget"], entry["binaries"]
    assert_equal "attestation", entry["verify"]
    assert_equal "checksums.txt", entry["checksums"]
    assert_equal "GregoireF.widget", entry["winget"]
    assert_equal "widget_{version}_linux_amd64.tar.gz", entry["assets"]["linux_amd64"]
    assert_equal "widget_{version}_windows_arm64.zip", entry["assets"]["windows_arm64"]
  end

  def test_checksum_level_without_provenance_and_no_winget_without_publisher
    _, entry = entry(attested: false)
    assert_equal "checksum", entry["verify"]
    refute entry.key?("winget")
  end

  def test_long_descriptions_are_cut_where_a_human_would
    long = "Find any project, run any task: one fuzzy search over every task of every project, for you"
    _, entry = entry(description: long)
    assert_equal "Find any project, run any task", entry["desc"]

    _, entry = entry(description: "word " * 30)
    assert_operator entry["desc"].length, :<=, 80
    refute entry["desc"].end_with?(" ")
  end

  def test_refuses_what_it_cannot_infer
    assert_raises(Tap::Error) { entry(license: nil) }
    assert_raises(Tap::Error) { entry(license: "NOASSERTION") }
    assert_raises(Tap::Error) { entry(description: "widget does things") }

    files = goreleaser_files.reject { |n, _| n.include?("windows_arm64") }
    assert_match(/windows_arm64/, assert_raises(Tap::Error) { entry(files:) }.message)

    files = goreleaser_files.except("checksums.txt")
    assert_match(/no checksums file/, assert_raises(Tap::Error) { entry(files:) }.message)
  end

  def test_no_release
    gh = FakeGitHub.new({})
    assert_raises(Tap::Error) { Tap::Onboard.new(github: gh).entry(REPO) }
  end

  def test_yaml_round_trips_through_the_config
    name, entry = entry(publisher: "Grégoire Favreau")
    text = "publisher: Grégoire Favreau\ntools:#{Tap::Onboard.yaml(name, entry)}"
    parsed = YAML.safe_load(text)
    assert_equal entry, parsed["tools"]["widget"]
    Dir.mktmpdir do |dir|
      File.binwrite(File.join(dir, "tools.yml"), text)
      assert_equal ["widget"], Tap::Config.load(File.join(dir, "tools.yml")).map(&:name)
    end
  end
end
