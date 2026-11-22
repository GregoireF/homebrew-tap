# ADR-0005: sync, not `brew bump`, publishes new versions

**Status:** accepted (2026-11-22)

## Context

The `brew tap-new` template of Homebrew 7 includes an autobump workflow:
`brew bump --open-pr` reads each formula's livecheck and opens one pull
request per new version, for a person to review and merge (bottles then go
through `brew pr-pull`).

## Decision

Keep `sync.yml`. It does what a reviewer would and more, without a pull
request: SHA-256 against the release's checksums, SLSA provenance of every
archive, real installs on every platform and package manager, a signed
commit, and a provenance of every published file. The formulae keep their
`livecheck` block, so `brew livecheck` and `brew bump --dry-run` still work.

## Consequences

- No pull request to merge for a routine version; the owner is never the
  bottleneck.
- The tap does not use `brew pr-pull` or bottles: every formula installs a
  prebuilt archive.
- The workflows otherwise follow the template: `brew test-bot
  --only-tap-syntax`, `Homebrew/actions` pinned to a dated release.
