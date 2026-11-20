# ADR-0004: the tap writes the WinGet manifests; komac submits them

**Status:** accepted (2026-11-20)

## Context

WinGet has no taps: a package lives in microsoft/winget-pkgs, through a pull
request reviewed by its moderators. addlicense had its own repository,
GregoireF/addlicense-winget, triggered by a `repository_dispatch` (one more
token) and running `wingetcreate`; its first submission never landed.

## Decision

The tap renders the manifests (`winget/manifests/<letter>/<Publisher>/<Name>/<version>/`,
schema 1.10.0, zip archive installed as a portable package with one alias
per binary) from the same verified lock as the formulae, checks them with
`winget validate` on the Windows runners, and after each publication
`komac submit` (pinned release, SHA-256 checked) opens the pull request.

## Consequences

- One secret, `WINGET_TOKEN`, in the `winget` environment of the tap: a
  personal access token with `public_repo`, because the pull request comes
  from the owner's fork of winget-pkgs. Until it exists the job only prints
  a notice.
- A new package waits for WinGet's moderators; later versions usually merge
  automatically. The catalog says so.
- GregoireF/addlicense-winget and the `DISPATCH_TOKEN` entry for it can be
  archived once the first submission from the tap is merged.
