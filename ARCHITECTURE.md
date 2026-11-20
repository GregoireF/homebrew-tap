# Architecture

```text
 producer repos                    GregoireF/homebrew-tap
 (ship-it, kiwa, addlicense,
  any repo with the                tools.yml ──────────────┐   how to package each tool
  gregoiref-tap topic)             tools.lock.json ──────┐ │   versions, dates, SHA-256 served
                                                          │ │
 v1.2.3 tag → release workflow     bin/tap render ◄───────┴─┘   pure: same inputs, same bytes
   archives, checksums,              ├─ Formula/<tool>.rb        Homebrew (macOS, Linux)
   SLSA provenance                   ├─ bucket/<tool>.json       Scoop (Windows)
          │                          ├─ winget/manifests/…       WinGet (Windows)
          │  every 30 min            └─ README.md (tools table)
          └──────────────► sync.yml
                             │
   discover --add ─► sync ─► install test ─► signed commit ─► site (Pages)
                                                         └──► komac → winget-pkgs
```

## Files

| Path | Role | Edited by |
| --- | --- | --- |
| `tools.yml` | One entry per tool: repository, binaries, archive names, verification level, completions, WinGet id | the owner, or `bin/tap add` |
| `schema/tools.schema.json` | JSON Schema of `tools.yml` for editors; kept in step with `config.rb` by a test | the owner |
| `tools.lock.json` | Version, tag, date and SHA-256 of every archive currently served | `bin/tap sync` |
| `Formula/*.rb`, `bucket/*.json`, `winget/manifests/**` | Homebrew formulae, Scoop and WinGet manifests | `bin/tap render` |
| `README.md` | Hand-written, except between the `GENERATED: tools` markers | both |
| `templates/` | The formula template and the site's templates | the owner |
| `tap_migrations.json` | Tells Homebrew that the old `addlicense` cask is now a formula | the owner |
| `lib/tap/` | The generator, Ruby standard library only | the owner |
| `.githooks/` | `pre-commit` (rake) and `commit-msg` (header format); `git config core.hooksPath .githooks` | the owner |

## The generator (`lib/tap/`)

| File | Does |
| --- | --- |
| `config.rb` | Loads and validates `tools.yml` (including `brew audit`'s desc rules) |
| `lock.rb` | Reads and writes `tools.lock.json` |
| `github.rb` | Latest release, repository metadata, attestation lookup, downloads, topic search; the token goes to the API host only |
| `checksums.rb` | Parses sha256sum files (GoReleaser and cargo-dist formats) |
| `verifier.rb` | `gh attestation verify` |
| `sync.rb` | Download, hash, cross-check, verify, refuse downgrades |
| `render.rb` | Lock → formulae, Scoop manifests, README table |
| `winget.rb` | Lock → WinGet manifests (1.10.0, portable zip) in winget-pkgs' layout |
| `onboard.rb` | A `tools.yml` entry inferred from a release (`bin/tap add`, `discover --add`) |
| `health.rb` | Stale tools, lost provenance, checksum-only tools that could be verified |
| `site.rb` | The catalog: index, one page per tool, Atom feed |
| `commit_lint.rb` | ship-it's header rules, for the `commit-msg` hook |
| `cli.rb` | `bin/tap sync | render | check | add | discover | health | site | lint-commit` |

`render` is pure, so `bin/tap check` (run by `rake` and CI) fails as soon as a
generated file differs from what the generator writes, or a stray one (an
old WinGet version) is left: nobody can hand-edit a formula by mistake.

## Workflows

| Workflow | When | Does |
| --- | --- | --- |
| `sync.yml` | every 30 min | discover → detect → install test → signed commit to `main` → site → WinGet submission |
| `install-test.yml` | nightly, and called by sync | `brew install` + `brew test` on 4 runners, `scoop install` and `winget validate` on 2; health checks; one issue per problem kind, closed when it is gone |
| `pages.yml` | called by sync, push | `bin/tap site` → GitHub Pages |
| `ci.yml` | push, pull request | tests and coverage, drift check, `brew style`, `brew audit --strict --online`, license headers (addlicense), commit header (ship), actionlint, zizmor, Dependabot automerge |
| `codeql.yml` | weekly, push, pull request | CodeQL for Ruby and Actions |
| `scorecard.yml` | weekly, push | OpenSSF Scorecard |

## Secrets and environments

| Environment | Secret | Used by | Without it |
| --- | --- | --- | --- |
| `publish` | `TAP_SIGNING_KEY` (SSH, signing only) | `sync.yml` publish | publish fails loudly |
| `winget` | `WINGET_TOKEN` (PAT, `public_repo`) | `sync.yml` winget | submission skipped with a notice |
| `github-pages` | none | `pages.yml` deploy | |

## Decisions

See [`docs/adr/`](docs/adr/).
