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

task default: [:test, :check]
