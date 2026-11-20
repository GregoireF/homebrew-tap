# ADR-0001: the tap pulls releases; producers only release

**Status:** accepted (2026-11-20)

## Context

Until November 2026 each producer pushed its own files into the tap, three
different ways: GoReleaser's `homebrew_casks` with a personal access token
(addlicense), a shell script plus an SSH deploy key (ship-it) and a cargo-dist
custom job plus an SSH deploy key (kiwa). Each repository held a secret that
could write to the tap, the formats drifted, nothing was tested, and the
README listed one tool out of three.

## Decision

`tools.yml` describes every tool. A scheduled workflow in the tap
(`sync.yml`, every 30 minutes) reads the latest stable release of each tool,
verifies it, generates the files, tests real installs, then commits.
Producers keep no token that writes to the tap.

Polling rather than `repository_dispatch`: a dispatch needs a token with
write access to the tap in every producer, which is what we remove.

## Consequences

- A release appears in the tap within 30 minutes instead of seconds.
- Adding a tool is one `tools.yml` entry; the producer does nothing.
- The tap is the single place that decides what gets published, so it is
  also the single place that verifies provenance.
