# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"

class TargetsTest < Minitest::Test
  include TestHelpers

  def test_formula_golden
    t = tool(binaries: %w[demo dm], caveats: "Needs git 2.43. Run `demo doctor`.")
    assert_golden "demo.rb", Tap::Targets::Homebrew.formula(t, release(tool: t))
  end

  def test_scoop_golden
    t = tool(binaries: %w[demo dm], caveats: "Needs git 2.43. Run `demo doctor`.")
    assert_golden "demo.json", Tap::Targets::Scoop.manifest(t, release(tool: t))
  end

  def test_formula_without_caveats_has_no_caveats_method
    refute_match(/def caveats/, Tap::Targets::Homebrew.formula(tool, release))
  end

  def test_completions
    formula = Tap::Targets::Homebrew.formula(tool(completions: ["completions"]), release)
    assert_includes formula, '    generate_completions_from_executable(bin/"demo", "completions")'
    refute_match(/generate_completions/, Tap::Targets::Homebrew.formula(tool, release))
  end

  def test_license_expressions
    assert_match(/license "MIT"$/, Tap::Targets::Homebrew.formula(tool, release))
    assert_match(/license any_of: \["MIT", "Apache-2.0"\]/,
                 Tap::Targets::Homebrew.formula(tool(license: "MIT OR Apache-2.0"), release))
    assert_match(/license all_of: \["MIT", "BSD-3-Clause"\]/,
                 Tap::Targets::Homebrew.formula(tool(license: "MIT AND BSD-3-Clause"), release))
    assert_raises(Tap::Error) { Tap::Targets::Homebrew.formula(tool(license: "MIT OR Apache-2.0 AND X"), release) }
  end

  def test_strings_are_escaped_for_ruby
    formula = Tap::Targets::Homebrew.formula(tool(desc: "Says \"hi\" for \#{x}"), release)
    assert_includes formula, 'desc "Says \"hi\" for \#{x}"'
  end

  def test_test_command_without_arguments
    assert_includes Tap::Targets::Homebrew.formula(tool(test: []), release), "shell_output(\"\#{bin}/demo\")"
  end

  def test_readme_section_replaces_only_the_generated_part
    lock = Tap::Lock.new("unused", { "demo" => release })
    readme = "intro\n#{Tap::Targets::Readme::START}\nstale\n#{Tap::Targets::Readme::STOP}\noutro\n"
    out = Tap::Targets::Readme.section(catalog([tool], lock, readme: readme))
    assert out.start_with?("intro\n")
    assert out.end_with?("#{Tap::Targets::Readme::STOP}\noutro\n")
    refute_includes out, "stale"
    assert_includes out, "[1.2.3](https://github.com/GregoireF/demo/releases/tag/v1.2.3)"
    assert_includes out, "SLSA provenance"
  end

  def test_readme_without_markers_fails
    assert_raises(Tap::Error) { Tap::Targets::Readme.section(catalog([tool], Tap::Lock.new("x", {}), readme: "no markers")) }
  end

  def test_tools_without_a_release_are_skipped
    files = repository_files([tool], Tap::Lock.new("x", {}),
                             readme: "#{Tap::Targets::Readme::START}\n#{Tap::Targets::Readme::STOP}\n")
    assert_equal ["README.md"], files.keys
  end
end
