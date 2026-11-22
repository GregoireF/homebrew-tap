# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/*_test.rb"]
  t.warning = true
end

desc "Fail if a generated file differs from what bin/tap render writes"
task :check do
  ruby "bin/tap", "check"
end

# brew style and brew audit --strict on this checkout, in Docker (any OS):
# once with the homebrew/brew image as it is, once after `brew update`,
# because the two Homebrew versions disagree on some cops (AGENTS.md).
BREW_CHECK = <<~SH
  set -u
  export HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1
  [ "$MODE" = latest ] && brew update -q >/dev/null 2>&1
  brew --version | head -n 1
  cp -r /src /tmp/tap && cd /tmp/tap && rm -rf .git && chmod -R go-w .
  git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm t
  export HOMEBREW_NO_AUTO_UPDATE=1
  brew tap gregoiref/tap /tmp/tap >/dev/null 2>&1
  if brew commands | grep -qx trust; then brew trust --tap gregoiref/tap >/dev/null; fi
  status=0
  brew style gregoiref/tap 2>&1 | grep -E "offenses|[.]rb:[0-9]+:[0-9]+" | grep -v "no offenses" && status=1
  brew audit --strict --online --tap gregoiref/tap || status=1
  exit $status
SH

desc "brew style and audit in Docker, on the current and the latest Homebrew"
task :brew do
  failed = %w[current latest].reject do |mode|
    puts "=== Homebrew #{mode}"
    system("docker", "run", "--rm", "-e", "MODE=#{mode}", "-v", "#{Dir.pwd}:/src:ro", "homebrew/brew:latest",
           "bash", "-c", BREW_CHECK)
  end
  abort "brew checks failed on: #{failed.join(", ")}" unless failed.empty?
end

task default: [:test, :check]
