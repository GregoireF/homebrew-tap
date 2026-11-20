# Roadmap

GregoireF/homebrew-tap is the **distribution hub** of the GregoireF tools: one
repository serves Homebrew (macOS and Linux), Scoop (Windows), the WinGet
manifests and a catalog site. It runs **without a human in the loop**: the
owner tags a release in a tool's repository, the tap does the rest.

## Principles

1. **The tap pulls; producers only release.** `tools.yml` says how to package
   each tool. Producers hold no secret that writes to the tap.
2. **Nothing unverified gets published.** A version reaches `main` only after
   its archives pass their SLSA provenance check (`gh attestation verify`) and
   real installs pass on macOS, Linux and Windows.
3. **Generated, never hand-edited.** Formulae, Scoop manifests, WinGet
   manifests, the README tables and the site come from `tools.yml` plus the
   release. CI fails when a generated file drifts.
4. **One author, every commit signed.** Automated commits are authored as the
   owner and signed with a CI-only SSH signing key; `main` requires signed
   commits. No co-author trailers.
5. **No PRs for routine work.** A new version is tested from a workflow
   artifact, then committed straight to `main`. The only pull request is
   Dependabot's, once a month, and it merges itself.
6. **Settings as code.** Repository settings, rulesets, environments and Pages
   are declared in [GregoireF/iac](https://github.com/GregoireF/iac).

## Current state (2026-11-20)

| | addlicense | ship | kiwa |
| --- | --- | --- | --- |
| Homebrew | Cask (Gatekeeper quarantines it on macOS) | Formula | Formula |
| Scoop | none | GoReleaser push | dist job push |
| WinGet | first submission never merged | none | none |
| Writes to the tap with | PAT `HOMEBREW_TAP_TOKEN` | SSH deploy key | SSH deploy key |
| SLSA provenance | none | yes | yes |
| Commit format | `Brew cask update for…` | `ship v0.1.2` | `📦️ build: kiwa 0.1.0` |

Before this overhaul the tap had no CI, no license, no tests, no signed
commits, and its README listed one tool out of three.

## Phase 1: tap foundations ✅

- [x] Roadmap and decisions ([`docs/adr/`](docs/adr/)).
- [x] `tools.yml`: one entry per tool (archives, binaries, verification level).
- [x] Ruby generator `bin/tap` (standard library only): `sync`, `render`,
      `check`, `discover`.
- [x] Formula template with `livecheck`; Scoop manifests with `notes`.
- [x] addlicense moves from Cask to Formula; `tap_migrations.json`.
- [x] Minitest suite, golden files, line coverage floor (90%; 100% today);
      `brew style` as the only linter.
- [x] CI: tests, drift check, `brew style`, `brew audit --strict --online`,
      license headers (addlicense), commit header (ship), actionlint, zizmor.
- [x] Generated README table; AGENTS.md; LICENSE-MIT and LICENSE-APACHE;
      SECURITY.md; ARCHITECTURE.md; issue template.

## Phase 2: hands-off publishing ✅

Verified on GitHub on 2026-11-20: `sync.yml` detects and verifies all three
tools; `install-test.yml` installs and tests them on the 6 runners, `winget
validate` passes on windows-2025, the health report is clean; the catalog
is live; `main` requires signed commits. The first automated publication
happens with the next stable release of a tool.

- [x] `sync.yml` (every 30 minutes, plus `workflow_dispatch`): detect and
      verify → install tests on the generated files → one signed commit
      pushed to `main`. The job's own `GITHUB_TOKEN` pushes: no GitHub App
      and no personal token are needed.
- [x] `install-test.yml`, reusable and nightly: `brew install` + `brew test` on
      macOS arm64, macOS x86_64, Linux x86_64 and Linux arm64; `scoop install`
      on Windows x64 and arm64. Nightly failures open a single issue.
- [x] Dependabot, monthly and grouped, with a 7-day cooldown; merged by CI.
- [x] OpenSSF Scorecard.
- [x] Producers stop pushing (GregoireF/ship-it#179, GregoireF/kiwa#58,
      GregoireF/addlicense#60 merged); `HOMEBREW_TAP_*` secrets and the tap's
      deploy keys deleted.
- [ ] addlicense's next release carries its build provenance; the nightly
      health report then asks to raise it to `verify: attestation`.
- [x] iac (GregoireF/iac#53): environment `publish` with `TAP_SIGNING_KEY`,
      ruleset `main-integrity` (signed commits, no force push, no deletion,
      no bypass), issues on. CI signing key on the account, private
      vulnerability reporting, Pages, environment `winget` with `WINGET_TOKEN`.
- [ ] Revoke the old `HOMEBREW_TAP_TOKEN` personal access token (by hand).
- [ ] iac's repository module: manage `homepage_url` (the profile's homepage
      is dropped by each apply until then).

## Phase 3: distribution hub ✅ (code ready, waits for the secrets)

- [x] WinGet: manifests generated in `winget/` (validated by `winget
      validate`), submitted by komac after each publication
      ([ADR-0004](docs/adr/0004-winget-from-the-tap.md)). Then archive
      `addlicense-winget`.
- [x] GitHub Pages catalog: one page per tool, install commands for each
      package manager, verification commands, Atom feed.
- [x] Discovery: the `gregoiref-tap` topic is enough; `bin/tap discover --add`
      infers the entry and the usual pipeline publishes it.
- [x] Shell completions (bash, zsh, fish) for kiwa and addlicense.
- [x] JSON Schema for `tools.yml`.
- Bottles are not needed: every formula ships prebuilt binaries.

## Phase 4: upkeep on autopilot

- [x] CodeQL (Ruby and Actions).
- [x] Health report: stale tools, lost provenance, checksum-only tools that
      could be verified; one issue, closed when healthy again.
- [x] Local hooks: `rake` before each commit, header format and no AI
      co-author in the message.
- [ ] Clean-up: delete workflow runs older than 90 days.
- [ ] Yearly rotation reminder for `TAP_SIGNING_KEY`.

## Ideas to evaluate

- `ship completion <shell>` in ship-it, then `completions:` in tools.yml.
- A second binary and `test` arguments detected by `bin/tap add` from the
  archive contents.
- Nix flake (`nix run github:GregoireF/homebrew-tap#kiwa`) generated from
  `tools.yml`.
- mise/aqua registry entries.
- A shell installer at `gregoiref.github.io/homebrew-tap/install.sh` that
  checks provenance before it installs.
- Man pages, once the tools ship them in their archives.
## Outside this repository

- Remove the AI co-author trailers from history in every
  GregoireF repository except the Go modules (addlicense keeps its tagged
  commits so `sum.golang.org` stays valid). One repository at a time, mirror
  backup first, every rewritten commit re-signed.
