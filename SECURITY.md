# Security policy

## Reporting a vulnerability

Please **do not open a public issue**. Report it privately through
[GitHub's private vulnerability reporting](https://github.com/GregoireF/homebrew-tap/security/advisories/new).
You will get an acknowledgement within 5 working days.

A vulnerability in a tool itself (ship, kiwa, addlicense) belongs to that
tool's repository; report it there the same way.

## What the tap guarantees

- **Every archive is hashed by the tap.** `bin/tap sync` downloads each
  archive, computes its SHA-256 and compares it with the release's checksums
  file. That SHA-256 is what goes into the formula or the manifest; Homebrew
  and Scoop then refuse any other bytes.
- **Signed build provenance.** For tools marked `verify: attestation` in
  [`tools.yml`](tools.yml), each archive must carry a SLSA provenance signed
  by a GitHub Actions workflow of the tool's own repository
  (`gh attestation verify`). An archive without one is not published.
- **No downgrade.** The tap refuses a "latest" release older than the version
  it serves.
- **Tested before it is published.** A new version reaches `main` only after
  real installs pass on macOS, Linux and Windows.
- **Signed history.** Every commit on `main` is signed and verified by GitHub:
  the owner's own commits, automated ones (owner's CI signing key, held in the
  `publish` environment) and Dependabot's squash merges (signed by GitHub).
- **No write access for producers.** The tools' repositories hold no token
  that can write here; the tap pulls their releases.
- **Two secrets, each in its own environment.** `TAP_SIGNING_KEY` (signs
  commits, environment `publish`) and `WINGET_TOKEN` (opens pull requests on
  microsoft/winget-pkgs from the owner's fork, environment `winget`). The
  jobs that read them run no code from a pull request.
- **Hardened workflows.** Actions are pinned by commit, permissions are
  declared per job, and every workflow is checked by
  [zizmor](https://docs.zizmor.sh) and actionlint.
  [OpenSSF Scorecard](https://scorecard.dev/viewer/?uri=github.com/GregoireF/homebrew-tap)
  scores the repository weekly.

## Verify a download yourself

```sh
gh attestation verify <archive> --repo GregoireF/<tool-repository>
```
