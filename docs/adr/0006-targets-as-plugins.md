# ADR-0006: one target per output

**Status:** accepted (2026-11-22)

## Context

The generator started with formulae, Scoop manifests and a README table in
one module, then gained WinGet and a site, each wired in its own way. Nix,
aqua, an API, badges, an installer and reference pages were next.

## Decision

Every output is a module under `lib/tap/targets/` with the same interface:

```ruby
module Tap::Targets::Example
  GLOBS = %w[example/*.json].freeze   # paths it owns
  def self.files(catalog) = { "example/kiwa.json" => "…" }
end
```

`Targets.repository` lists the committed ones (rendered and drift-checked
by `bin/tap render` / `check`, carried by sync); `Targets.site` lists the
ones written to the Pages artifact. A `Catalog` (tools, lock, README,
status) is all a target reads: targets are pure.

## Consequences

- A new package manager is one file, one name in a list, a test and an
  install job.
- Stray files under a target's `GLOBS` (an old WinGet version) are removed
  by `render` and reported by `check`.
- The reference pages are a target too, so they follow their schemas.
