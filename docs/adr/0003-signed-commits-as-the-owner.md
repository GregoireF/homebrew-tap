# ADR-0003: automated commits are the owner's, signed by a CI key

**Status:** accepted (2026-11-20)

## Context

The owner is the only contributor and signs every commit. Earlier automated
commits came from `github-actions[bot]`, `goreleaserbot` and "kiwa release",
none of them signed. A GitHub App would sign through the API, but its bot
would then show up as a contributor.

## Decision

`sync.yml`'s publish job commits as `Grégoire FAVREAU
<16638358+GregoireF@users.noreply.github.com>` and signs with an SSH key used
only by CI: secret `TAP_SIGNING_KEY` of the `publish` environment, its public
half registered as a **signing key** of the GregoireF account
(`gh ssh-key add --type signing`: the Terraform provider has no resource for
it). The secret, the environment and the ruleset are declared in
GregoireF/iac (`terraform/github/tap.tf`). It pushes with the job's
`GITHUB_TOKEN`; no App, no personal token.

The `main` ruleset requires signed commits and forbids force pushes and
deletion, for everyone. Dependabot's squash merges are signed by GitHub.

## Consequences

- History: one author, every commit "Verified".
- The CI key can only sign; revoking it on the account is enough to stop it.
  Rotate it yearly.
- A push by `GITHUB_TOKEN` does not trigger other workflows, so sync runs the
  tests itself before it pushes.
