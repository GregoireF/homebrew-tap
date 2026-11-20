# ADR-0002: the generator is Ruby, standard library only

**Status:** accepted (2026-11-20)

## Context

Formulae are Ruby, Homebrew ships its own Ruby, and `brew style` (RuboCop
with Homebrew's rules) lints any Ruby file in a tap. Go (ship-it, addlicense)
and Rust (kiwa) were the alternatives.

## Decision

Ruby 3.4, standard library only: `yaml`, `json`, `erb`, `net/http`,
`digest`, `open3`, `minitest` and `coverage`. No Gemfile. `brew style` is the
only linter.

## Consequences

- Nothing to install besides Ruby; Dependabot has no gems to watch.
- Homebrew's style rules apply to the generator too, including the Sorbet
  sigil (`# typed: strict`) and its `Data.define` conventions.
- Line coverage is measured with the `coverage` library, with a 90% floor
  enforced by the test helper.
