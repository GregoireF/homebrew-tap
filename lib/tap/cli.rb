# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

module Tap
  # bin/tap: the commands CI and the owner run.
  class CLI
    USAGE = <<~TXT
      usage: bin/tap <command>

        sync               fetch the latest stable releases, verify them, update
                           tools.lock.json and rewrite the generated files
        render             rewrite the generated files from tools.yml and the lock
        check              fail if a generated file differs from what render writes
        add REPO           append a tools.yml entry inferred from REPO's latest release
        discover [--add]   list (or add) repositories with the gregoiref-tap topic
                           that are not in tools.yml yet
        health             report stale tools and provenance problems (exit 1 if any)
        site DIR           write the catalog site into DIR
        lint-commit FILE   check a commit message (the commit-msg hook)

      sync writes `changed`, `tools` and `message` to $GITHUB_OUTPUT when set;
      health writes `report`.
    TXT

    HEADER_MAX = 72
    TOPIC = "gregoiref-tap"
    # Every file under these globs must come from `render`; `check` flags strays
    # (a removed tool, an old WinGet version).
    GENERATED_GLOBS = %w[Formula/*.rb bucket/*.json winget/manifests/**/*.yaml].freeze

    def initialize(root: Render::ROOT, out: $stdout, err: $stderr, github: nil, verifier: nil)
      @root = root
      @out = out
      @err = err
      @github = github
      @verifier = verifier
    end

    def run(argv)
      command = argv.first
      case command
      when "sync" then sync
      when "render" then render
      when "check" then check
      when "discover" then discover(auto_add: argv.include?("--add"))
      when "add" then add(argv.fetch(1) { raise Error, "usage: bin/tap add OWNER/REPO" })
      when "health" then health
      when "site" then site(argv.fetch(1) { raise Error, "usage: bin/tap site DIR" })
      when "lint-commit" then lint_commit(argv.fetch(1) { raise Error, "usage: bin/tap lint-commit FILE" })
      else
        @err.puts USAGE
        (command.nil? || %w[-h --help help].include?(command)) ? 0 : 2
      end
    rescue Error => e
      @err.puts "tap: #{e.message}"
      1
    end

    def self.commit_message(updates)
      header =
        if updates.size == 1
          u = updates.first
          u.from ? "⬆️ build(#{u.tool}): #{u.to}" : "✨ feat(#{u.tool}): add #{u.to}"
        else
          list = updates.map { |u| "#{u.tool} #{u.to}" }.join(", ")
          candidate = "⬆️ build(tools): #{list}"
          (candidate.length <= HEADER_MAX) ? candidate : "⬆️ build(tools): #{updates.size} updates"
        end
      body = updates.map { |u| "- #{u.tool}: #{u.from || "new"} -> #{u.to}" }.join("\n")
      "#{header}\n\n#{body}\n"
    end

    private

    def tools = Config.load(path("tools.yml"))

    def lock = @lock ||= Lock.load(path("tools.lock.json"))

    def github = @github ||= GitHub.new

    def path(rel) = File.join(@root, rel)

    # Binary reads and writes everywhere: LF on every platform, so `check`
    # gives the same answer on Windows as in CI.
    def read(rel)
      full = path(rel)
      File.binread(full).force_encoding(Encoding::UTF_8) if File.exist?(full)
    end

    def generated = Render.files(tools, lock, readme: read("README.md") || "")

    # Writes every generated file and deletes generated files that are no
    # longer produced (an old WinGet version, a removed tool).
    def render
      files = generated
      files.each { |rel, content| write(rel, content) }
      stray_files(files).each do |rel|
        File.delete(path(rel))
        @err.puts "removed #{rel}"
      end
      prune_empty_dirs("winget")
      0
    end

    def stray_files(files)
      GENERATED_GLOBS.flat_map { |glob| Dir[path(glob)] }.map { |f| f.delete_prefix("#{@root}/") } - files.keys
    end

    def prune_empty_dirs(rel)
      Dir[path("#{rel}/**/")].sort_by { |d| -d.length }.each do |dir|
        Dir.rmdir(dir) if Dir.empty?(dir)
      end
    end

    def check
      files = generated
      drift = files.reject { |rel, content| read(rel) == content }
      stale = stray_files(files)
      return 0 if drift.empty? && stale.empty?

      drift.each_key { |rel| @err.puts "tap: #{rel} is out of date, run bin/tap render" }
      stale.each { |rel| @err.puts "tap: #{rel} is not generated from tools.yml, run bin/tap render" }
      1
    end

    def sync
      updates = Sync.new(lock:, github:, verifier: @verifier || Verifier.new, log: @err).run(tools)
      if updates.empty?
        @out.puts "everything up to date"
        output(changed: "false")
        return 0
      end

      lock.save
      render
      message = self.class.commit_message(updates)
      @out.puts message
      output(changed: "true", tools: updates.map(&:tool).join(" "), message:)
      0
    end

    # With add: each new repository is added when its entry can be inferred;
    # one that cannot is reported and skipped, so the sync goes on.
    def discover(auto_add: false)
      known = tools.map(&:repo)
      found = github.repos_with_topic("GregoireF", TOPIC) - known
      found.each do |repo|
        next @out.puts(repo) unless auto_add

        begin
          add(repo)
        rescue Error => e
          @err.puts "tap: skipped #{repo}: #{e.message}"
        end
      end
      0
    end

    def add(repo)
      raise Error, "#{repo} is already in tools.yml" if tools.any? { |t| t.repo == repo }

      name, entry = Onboard.new(github:, publisher: publisher).entry(repo)
      raise Error, "a tool named #{name} is already in tools.yml" if tools.any? { |t| t.name == name }

      text = read("tools.yml")
      File.binwrite(path("tools.yml"), "#{text.chomp}\n#{Onboard.yaml(name, entry)}")
      @err.puts "added #{name} (#{repo}) to tools.yml"
      0
    end

    def publisher = YAML.safe_load(read("tools.yml"))["publisher"]

    def health
      findings = Health.new(github:).run(tools, lock)
      report = Health.report(findings)
      @out.print report
      output(report:)
      findings.empty? ? 0 : 1
    end

    def site(dir)
      Site.files(tools, lock).each do |rel, content|
        full = File.join(dir, rel)
        FileUtils.mkdir_p(File.dirname(full))
        File.binwrite(full, content)
      end
      @err.puts "wrote the site to #{dir}"
      0
    end

    def lint_commit(file)
      problems = CommitLint.problems(File.binread(file).force_encoding(Encoding::UTF_8))
      problems.each { |p| @err.puts "commit message: #{p}" }
      problems.empty? ? 0 : 1
    end

    def write(rel, content)
      return if read(rel) == content

      full = path(rel)
      FileUtils.mkdir_p(File.dirname(full))
      File.binwrite(full, content)
      @err.puts "wrote #{rel}"
    end

    def output(**values)
      (file = ENV.fetch("GITHUB_OUTPUT", nil)) || return
      File.open(file, "ab") do |f|
        values.each do |key, value|
          delimiter = "EOF_#{key.upcase}"
          f.puts "#{key}<<#{delimiter}", value.to_s.chomp, delimiter
        end
      end
    end
  end
end
