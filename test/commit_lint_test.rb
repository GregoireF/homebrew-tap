# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require_relative "test_helper"

class CommitLintTest < Minitest::Test
  def problems(message) = Tap::CommitLint.problems(message)

  def test_accepts_the_conventions
    assert_empty problems("✨ feat(site): add an Atom feed\n\nBody.\n")
    assert_empty problems("⬆️ build(kiwa): 0.2.0\n")
    assert_empty problems("fix: plain conventional commit\n")
    assert_empty problems("# comment from git\n♻️ refactor(cli)!: split commands\n")
  end

  def test_leaves_git_messages_alone
    assert_empty problems("Merge branch 'main'\n")
    assert_empty problems("fixup! ✨ feat: x\n")
  end

  def test_rejects
    assert_match(/must look like/, problems("update stuff\n").first)
    assert_match(/unknown type/, problems("✨ feature: x\n").first)
    assert_match(/subject is 51 characters/, problems("feat: #{"x" * 51}\n").first)
    assert_match(/header is/, problems("✨ feat(a-very-long-scope-name-indeed): #{"x" * 45}\n").first)
    assert_match(/period/, problems("docs: fix typo.\n").first)
    assert_match(/AI co-author/,
                 problems("feat: x\n\nCo-authored-by: Claude <noreply@anthropic.com>\n").first)
  end
end
