# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"

class RenderTest < Minitest::Test
  include TestHelpers

  def test_formula_golden
    t = tool(binaries: %w[demo dm], caveats: "Needs git 2.43. Run `demo doctor`.")
    assert_golden "demo.rb", Tap::Render.formula(t, release(tool: t))
  end

  def test_scoop_golden
    t = tool(binaries: %w[demo dm], caveats: "Needs git 2.43. Run `demo doctor`.")
    assert_golden "demo.json", Tap::Render.scoop(t, release(tool: t))
  end

  def test_formula_without_caveats_has_no_caveats_method
    refute_match(/def caveats/, Tap::Render.formula(tool, release))
  end

  def test_completions
    formula = Tap::Render.formula(tool(completions: ["completions"]), release)
    assert_includes formula, '    generate_completions_from_executable(bin/"demo", "completions")'
    refute_match(/generate_completions/, Tap::Render.formula(tool, release))
  end

  def test_license_expressions
    assert_match(/license "MIT"$/, Tap::Render.formula(tool, release))
    assert_match(/license any_of: \["MIT", "Apache-2.0"\]/,
                 Tap::Render.formula(tool(license: "MIT OR Apache-2.0"), release))
    assert_match(/license all_of: \["MIT", "BSD-3-Clause"\]/,
                 Tap::Render.formula(tool(license: "MIT AND BSD-3-Clause"), release))
    assert_raises(Tap::Error) { Tap::Render.formula(tool(license: "MIT OR Apache-2.0 AND X"), release) }
  end

  def test_strings_are_escaped_for_ruby
    formula = Tap::Render.formula(tool(desc: "Says \"hi\" for \#{x}"), release)
    assert_includes formula, 'desc "Says \"hi\" for \#{x}"'
  end

  def test_test_command_without_arguments
    assert_includes Tap::Render.formula(tool(test: []), release), "shell_output(\"\#{bin}/demo\")"
  end

  def test_readme_section_replaces_only_the_generated_part
    lock = Tap::Lock.new("unused", { "demo" => release })
    readme = "intro\n#{Tap::Render::README_START}\nstale\n#{Tap::Render::README_END}\noutro\n"
    out = Tap::Render.readme_section(readme, [tool], lock)
    assert out.start_with?("intro\n")
    assert out.end_with?("#{Tap::Render::README_END}\noutro\n")
    refute_includes out, "stale"
    assert_includes out, "[1.2.3](https://github.com/GregoireF/demo/releases/tag/v1.2.3)"
    assert_includes out, "SLSA provenance"
  end

  def test_readme_without_markers_fails
    assert_raises(Tap::Error) { Tap::Render.readme_section("no markers", [tool], Tap::Lock.new("x", {})) }
  end

  def test_tools_without_a_release_are_skipped
    files = Tap::Render.files([tool], Tap::Lock.new("x", {}),
                              readme: "#{Tap::Render::README_START}\n#{Tap::Render::README_END}\n")
    assert_equal ["README.md"], files.keys
  end
end
