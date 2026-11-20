# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"

class CLITest < Minitest::Test
  include TestHelpers

  Update = Tap::Sync::Update

  def test_commit_message_for_one_upgrade
    msg = Tap::Commands::Sync.commit_message([Update.new(tool: "kiwa", from: "0.1.0", to: "0.2.0")])
    assert_equal "⬆️ build(kiwa): 0.2.0\n\n- kiwa: 0.1.0 -> 0.2.0\n", msg
  end

  def test_commit_message_for_a_new_tool
    msg = Tap::Commands::Sync.commit_message([Update.new(tool: "kiwa", from: nil, to: "0.1.0")])
    assert msg.start_with?("✨ feat(kiwa): add 0.1.0\n")
  end

  def test_commit_message_for_several_tools_stays_within_72_characters
    few = [Update.new(tool: "kiwa", from: "1", to: "2"), Update.new(tool: "ship", from: "1", to: "2")]
    assert_equal "⬆️ build(tools): kiwa 2, ship 2", Tap::Commands::Sync.commit_message(few).lines.first.chomp

    many = (1..9).map { |i| Update.new(tool: "tool-number-#{i}", from: "1.0.0", to: "1.0.1") }
    header = Tap::Commands::Sync.commit_message(many).lines.first.chomp
    assert_equal "⬆️ build(tools): 9 updates", header
  end

  def test_the_repository_is_up_to_date
    err = StringIO.new
    assert_equal 0, Tap::CLI.new(out: StringIO.new, err:).run(["check"]), err.string
  end

  def test_check_reports_drift_and_stray_files
    Dir.mktmpdir do |root|
      %w[tools.yml tools.lock.json README.md].each { |f| FileUtils.cp(File.join(ROOT, f), root) }
      %w[Formula bucket winget].each { |d| FileUtils.cp_r(File.join(ROOT, d), root) }
      File.binwrite(File.join(root, "Formula/ship.rb"), "# edited by hand\n")
      File.binwrite(File.join(root, "bucket/stray.json"), "{}\n")
      old = File.join(root, "winget/manifests/g/GregoireF/kiwa/0.0.1")
      FileUtils.mkdir_p(old)
      File.binwrite(File.join(old, "GregoireF.kiwa.yaml"), "old\n")

      err = StringIO.new
      assert_equal 1, Tap::CLI.new(root:, out: StringIO.new, err:).run(["check"])
      assert_includes err.string, "Formula/ship.rb is out of date"
      assert_includes err.string, "bucket/stray.json is not generated"
      assert_includes err.string, "winget/manifests/g/GregoireF/kiwa/0.0.1/GregoireF.kiwa.yaml is not generated"

      # render rewrites the edited file, removes the strays and their empty folder
      assert_equal 0, Tap::CLI.new(root:, out: StringIO.new, err: StringIO.new).run(["render"])
      refute File.exist?(File.join(root, "bucket/stray.json"))
      refute Dir.exist?(old)
      assert_equal 0, Tap::CLI.new(root:, out: StringIO.new, err: StringIO.new).run(["check"])
    end
  end

  DEMO_TOOLS = <<~YAML
    tools:
      demo:
        repo: GregoireF/demo
        desc: Shows how the tap works
        license: MIT
        binaries: [demo]
        test: [--version]
        verify: checksum
        checksums: checksums.txt
        assets:
          darwin_amd64: demo_darwin_amd64.tar.gz
          darwin_arm64: demo_darwin_arm64.tar.gz
          linux_amd64: demo_linux_amd64.tar.gz
          linux_arm64: demo_linux_arm64.tar.gz
          windows_amd64: demo_windows_amd64.zip
          windows_arm64: demo_windows_arm64.zip
  YAML

  def demo_release
    files = Tap::PLATFORMS.to_h { |p| ["demo_#{p}#{p.start_with?("windows") ? ".zip" : ".tar.gz"}", p] }
    sums = files.map { |name, bytes| "#{Digest::SHA256.hexdigest(bytes)}  #{name}\n" }.join
    { tag: "v0.3.0", files: files.merge("checksums.txt" => sums) }
  end

  def test_sync_writes_lock_files_and_github_output
    Dir.mktmpdir do |root|
      File.binwrite(File.join(root, "tools.yml"), DEMO_TOOLS)
      File.binwrite(File.join(root, "README.md"), "#{Tap::Targets::Readme::START}\n#{Tap::Targets::Readme::STOP}\n")
      output = File.join(root, "github_output")
      ENV["GITHUB_OUTPUT"] = output
      github = FakeGitHub.new({ "GregoireF/demo" => demo_release })
      cli = ->(out) { Tap::CLI.new(root:, out:, err: StringIO.new, github:, verifier: FakeVerifier.new) }

      out = StringIO.new
      assert_equal 0, cli.call(out).run(["sync"])
      assert_includes out.string, "✨ feat(demo): add 0.3.0"
      assert_includes File.binread(File.join(root, "Formula/demo.rb")), "/releases/download/v0.3.0/"
      assert File.exist?(File.join(root, "bucket/demo.json"))
      assert_includes File.binread(File.join(root, "tools.lock.json")), '"version": "0.3.0"'
      written = File.binread(output).force_encoding(Encoding::UTF_8)
      assert_includes written, "changed<<EOF_CHANGED\ntrue\nEOF_CHANGED\n"
      assert_includes written, "tools<<EOF_TOOLS\ndemo\nEOF_TOOLS\n"

      out = StringIO.new
      assert_equal 0, cli.call(out).run(["sync"])
      assert_includes out.string, "everything up to date"
      assert_includes File.binread(output), "changed<<EOF_CHANGED\nfalse\n"
    ensure
      ENV.delete("GITHUB_OUTPUT")
    end
  end

  def onboarding_github
    files = Tap::PLATFORMS.to_h do |p|
      os, arch = p.split("_")
      ["gadget_#{os}_#{arch}.#{(os == "windows") ? "zip" : "tar.gz"}", p]
    end
    sums = files.map { |n, b| "#{Digest::SHA256.hexdigest(b)}  #{n}\n" }.join
    FakeGitHub.new({ "GregoireF/gadget" => { tag: "v1.0.0", files: files.merge("checksums.txt" => sums) },
                     "GregoireF/broken" => { tag: "v1.0.0", files: { "notes.txt" => "" } } },
                   repos: { "GregoireF/gadget" => { description: "Does gadget things", license: "MIT", topics: [] },
                            "GregoireF/broken" => { description: "Broken", license: "MIT", topics: [] } })
  end

  def test_discover_add_appends_what_it_can_infer
    Dir.mktmpdir do |root|
      File.binwrite(File.join(root, "tools.yml"), "publisher: G\n#{DEMO_TOOLS}")
      err = StringIO.new
      cli = Tap::CLI.new(root:, out: StringIO.new, err:, github: onboarding_github)
      assert_equal 0, cli.run(%w[discover --add])
      assert_includes err.string, "added gadget (GregoireF/gadget)"
      assert_includes err.string, "skipped GregoireF/broken"

      tools = Tap::Config.load(File.join(root, "tools.yml"))
      assert_equal %w[demo gadget], tools.map(&:name)
      assert_equal "GregoireF.gadget", tools.last.winget

      err = StringIO.new
      assert_equal 1, Tap::CLI.new(root:, out: StringIO.new, err:, github: onboarding_github)
                              .run(%w[add GregoireF/gadget])
      assert_includes err.string, "already in tools.yml"
    end
  end

  def test_health_site_and_lint_commit
    Dir.mktmpdir do |root|
      %w[tools.yml tools.lock.json].each { |f| FileUtils.cp(File.join(ROOT, f), root) }
      out = StringIO.new
      ENV["GITHUB_OUTPUT"] = File.join(root, "out")
      status = Tap::CLI.new(root:, out:, err: StringIO.new, github: FakeGitHub.new({})).run(["health"])
      assert_equal 1, status # the fake holds no provenance at all
      assert_includes out.string, "no provenance any more"
      assert_includes File.binread(File.join(root, "out")), "report<<EOF_REPORT"

      site = File.join(root, "_site")
      assert_equal 0, Tap::CLI.new(root:, out: StringIO.new, err: StringIO.new).run(["site", site])
      assert File.exist?(File.join(site, "kiwa/index.html"))

      msg = File.join(root, "msg")
      File.binwrite(msg, "✨ feat(site): add it\n")
      assert_equal 0, Tap::CLI.new(root:, out: StringIO.new, err: StringIO.new).run(["lint-commit", msg])
      File.binwrite(msg, "stuff\n")
      err = StringIO.new
      assert_equal 1, Tap::CLI.new(root:, out: StringIO.new, err:).run(["lint-commit", msg])
      assert_includes err.string, "commit message: header must look like"

      err = StringIO.new
      assert_equal 1, Tap::CLI.new(root:, out: StringIO.new, err:).run(["site"])
      assert_includes err.string, "usage: bin/tap site DIR"
    ensure
      ENV.delete("GITHUB_OUTPUT")
    end
  end

  def test_discover_lists_unknown_repositories
    github = FakeGitHub.new({ "GregoireF/kiwa" => {}, "GregoireF/new-tool" => {} })
    out = StringIO.new
    assert_equal 0, Tap::CLI.new(out:, err: StringIO.new, github:).run(["discover"])
    assert_equal "GregoireF/new-tool\n", out.string
  end

  def test_usage
    err = StringIO.new
    assert_equal 2, Tap::CLI.new(out: StringIO.new, err:).run(["frobnicate"])
    assert_includes err.string, "usage: bin/tap"
    assert_equal 0, Tap::CLI.new(out: StringIO.new, err: StringIO.new).run(["--help"])
  end

  def test_errors_become_exit_code_1
    Dir.mktmpdir do |root|
      File.binwrite(File.join(root, "tools.yml"), "nope: 1\n")
      err = StringIO.new
      assert_equal 1, Tap::CLI.new(root:, out: StringIO.new, err:).run(["check"])
      assert_includes err.string, "top-level key `tools` missing"
    end
  end
end
