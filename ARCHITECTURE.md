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

Three layers, each depending only on the one above it:

| Layer | Files | Does |
| --- | --- | --- |
| Model | `config.rb`, `lock.rb`, `catalog.rb` | `tools.yml` (validated, including `brew audit`'s desc rules), `tools.lock.json`, and the `Catalog` every target renders from |
| Releases | `github.rb`, `checksums.rb`, `verifier.rb`, `sync.rb`, `onboard.rb`, `health.rb` | GitHub API (the token goes to the API host only), sha256sum files, `gh attestation verify`; download, hash, cross-check, verify, refuse downgrades; entries inferred from a release; nightly checks |
| Targets | `targets.rb`, `targets/*.rb` | One module per output, all with `files(catalog)` and `GLOBS`: `Homebrew`, `Scoop`, `Winget`, `Readme` (committed), `Pages` (site only) |
| Commands | `workspace.rb`, `commands.rb`, `commands/*.rb`, `cli.rb` | One class per `bin/tap` command, sharing a `Workspace` (files in binary mode, GitHub, `$GITHUB_OUTPUT`) |

Adding a package manager is one file under `targets/` and one name in
`Targets.repository` or `Targets.site`.

Targets are pure, so `bin/tap check` (run by `rake` and CI) fails as soon as
a generated file differs from what the generator writes, or a stray one (an
old WinGet version) is left under a target's `GLOBS`: nobody can hand-edit a
formula by mistake.

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
