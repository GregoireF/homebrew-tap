# ADR-0007: the addlicense formula is `gregoiref-addlicense`

**Status:** accepted (2026-11-22)

## Context

homebrew-core has an `addlicense` formula for google/addlicense, a
different tool with the same command name. `brew install addlicense`
installed Google's, and the two formulae cannot both be linked. Homebrew's
tap guide recommends a distinct name, its example being `<user>-<tool>`.

## Decision

The formula is `gregoiref-addlicense` (tools.yml `formula:`), it installs
the `addlicense` command and declares `conflicts_with "addlicense"`.
`formula_renames.json` maps the old formula name, `tap_migrations.json` the
old cask, to the new name. Scoop and WinGet keep `addlicense`: no clash
there.

## Consequences

- `brew install gregoiref/tap/addlicense` still resolves, to the new name.
- Users who want Google's tool and this one side by side cannot, with
  either package manager: both are called `addlicense`.
