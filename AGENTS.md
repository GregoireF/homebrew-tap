# AGENTS.md

Instructions for AI coding agents working on **GregoireF/homebrew-tap**
(format: [agents.md](https://agents.md/)). Read `ARCHITECTURE.md` first.

## What this repository is

The distribution hub of the GregoireF tools: Homebrew formulae (`Formula/`),
Scoop (`bucket/`), WinGet (`winget/`), Nix (`flake.nix`) and aqua
(`aqua/registry.yaml`) files, and a site (catalog, API, badges, `install.sh`),
all generated from `tools.yml` and `tools.lock.json` by the Ruby generator in
`lib/tap/`: one target module per output (`lib/tap/targets/`).

## Rules

- **Never edit `Formula/`, `bucket/`, `winget/`, `flake.nix`, `aqua/`,
  `docs/reference/`, `tools.lock.json` or the generated part of `README.md`
  by hand.** Change `tools.yml`, `templates/`
  or `lib/tap/`, then run `bin/tap render`.
- A new key in `tools.yml` goes into `lib/tap/config.rb` **and**
  `schema/tools.schema.json` (`test/schema_test.rb` fails otherwise).
- Ruby standard library only: no Gemfile, no gems.
- Style is Homebrew's: `brew style gregoiref/tap`. Its autocorrect has broken
  this code before (it rewrote methods inside `Data.define` blocks and
  activated an interpolation in a test): check the diff after `--fix`.
  Never take its `exclude?` suggestion: that method exists only inside
  Homebrew, and `bin/tap` runs on plain Ruby. Newer Homebrew versions flag a
  *private* method used once (`Homebrew/SingleUseMethod`) while older ones
  flag a directive that disables it as useless: helpers that are one named
  step are public instead. Check against both the Docker image as it is and
  after `brew update`.
- Files are read and written in binary mode (`File.binread`/`binwrite`):
  LF everywhere, on Windows too.
- Every Ruby file starts with `# typed: strict` then
  `# SPDX-License-Identifier: MIT OR Apache-2.0` (checked by addlicense).
- A fixed bug gets a test. `rake` must pass: tests, line coverage of `lib/` at
  90% or more, and `bin/tap check`.

## Build and test

```sh
rake                     # tests + coverage floor + bin/tap check
UPDATE_GOLDEN=1 rake test   # rewrite test/golden/ after an intended change
bin/tap render           # regenerate the files from tools.yml + lock
bin/tap sync             # network: fetch and verify the latest releases
bin/tap add OWNER/REPO   # network: append an inferred tools.yml entry
bin/tap health           # network: stale tools, provenance problems
bin/tap site _site       # the catalog site, API, badges, install.sh
rake brew                # brew style + audit in Docker, current and latest Homebrew
git config core.hooksPath .githooks   # once per clone: rake + header check
```

`install.sh` and the git hooks are POSIX `sh`; the end-to-end scripts
`test/installer.sh` and `test/aqua.sh` are bash, held to `brew style`
(shellcheck `--enable=all`, braces on every variable, `[[ ]]`, `.shellcheckrc`;
shfmt puts `then` and `do` on their own line). Every check outside Ruby:
`docs/how-to/work-on-the-tap.md`. Docs follow Diátaxis; new pages start from
`docs/templates/`.

## Commits

- Format: `✨ feat(scope): subject`, gitmoji first, then a Conventional
  Commits type; header at most 72 characters (checked by ship in CI).
- **No `Co-Authored-By` or any AI attribution trailer.** The owner is the
  only author; every commit is signed.
- Push to `main` directly; there is no pull-request workflow for the owner.

## Workflows

Actions are pinned by full commit SHA with the version in a comment, at a
release at least 7 days old. Every job starts with harden-runner (egress
audit) on Linux. Every
job declares its own `permissions`; `actions/checkout` uses
`persist-credentials: false`. `actionlint` and `zizmor` must stay clean.
