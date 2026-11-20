# GregoireF/homebrew-tap

[![CI](https://github.com/GregoireF/homebrew-tap/actions/workflows/ci.yml/badge.svg)](https://github.com/GregoireF/homebrew-tap/actions/workflows/ci.yml)
[![Install tests](https://github.com/GregoireF/homebrew-tap/actions/workflows/install-test.yml/badge.svg)](https://github.com/GregoireF/homebrew-tap/actions/workflows/install-test.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/GregoireF/homebrew-tap/badge)](https://scorecard.dev/viewer/?uri=github.com/GregoireF/homebrew-tap)

Homebrew formulae (macOS and Linux), a Scoop bucket and WinGet manifests
(Windows) for the command-line tools of [GregoireF](https://github.com/GregoireF),
from one repository. Catalog: **[gregoiref.github.io/homebrew-tap](https://gregoiref.github.io/homebrew-tap/)**
([Atom feed](https://gregoiref.github.io/homebrew-tap/feed.xml) of new versions).

Every version listed here was installed and tested on macOS, Linux and
Windows before it was published, and its archives were checked against the
release's checksums and, where the tool provides one, its signed SLSA build
provenance. Shell completions (bash, zsh, fish) come with the formulae of
the tools that provide them.

## Tools

<!-- BEGIN GENERATED: tools -->

| Tool | Description | Version | Homebrew | Scoop | Verified with |
| --- | --- | --- | --- | --- | --- |
| [`addlicense`](https://github.com/GregoireF/addlicense) | Fast, minimal license header manager for monorepos and CI pipelines | [1.0.1](https://github.com/GregoireF/addlicense/releases/tag/v1.0.1) | `brew install gregoiref/tap/addlicense` | `scoop install gregoiref/addlicense` | SHA-256 |
| [`kiwa`](https://github.com/GregoireF/kiwa) | Find any project, run any task: workspace launcher for humans and AI agents | [0.1.0](https://github.com/GregoireF/kiwa/releases/tag/v0.1.0) | `brew install gregoiref/tap/kiwa` | `scoop install gregoiref/kiwa` | SLSA provenance |
| [`ship`](https://github.com/GregoireF/ship-it) | You write the code, ship handles git and GitHub | [0.1.2](https://github.com/GregoireF/ship-it/releases/tag/v0.1.2) | `brew install gregoiref/tap/ship` | `scoop install gregoiref/ship` | SLSA provenance |

<!-- END GENERATED: tools -->

## Install

### Homebrew (macOS, Linux)

```sh
brew install gregoiref/tap/<tool>
```

or add the tap once, then use short names:

```sh
brew tap gregoiref/tap
brew install <tool>
```

### Scoop (Windows)

```powershell
scoop bucket add gregoiref https://github.com/GregoireF/homebrew-tap
scoop install gregoiref/<tool>
```

### WinGet (Windows)

```powershell
winget install --id GregoireF.<tool> --exact
```

The tap submits each version to [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs);
it becomes installable once WinGet's moderators merge it.

### Upgrade

```sh
brew upgrade            # Homebrew
scoop update '*'        # Scoop
winget upgrade --all    # WinGet
```

## Verify a download yourself

Tools marked "SLSA provenance" publish a signed build attestation for every
archive. With the [GitHub CLI](https://cli.github.com/):

```sh
gh release download v0.1.2 --repo GregoireF/ship-it --pattern 'ship_0.1.2_linux_amd64.tar.gz'
gh attestation verify ship_0.1.2_linux_amd64.tar.gz --repo GregoireF/ship-it
```

## addlicense: moving from the cask to the formula

addlicense used to be a cask, and macOS quarantines what a cask installs:
the unsigned binary could refuse to start. It is a formula now. If you
installed the cask:

```sh
brew uninstall --cask addlicense
brew install gregoiref/tap/addlicense
```

## How this tap works

Nobody edits the files under `Formula/`, `bucket/` and `winget/`.
[`tools.yml`](tools.yml) describes each tool; every 30 minutes a workflow
looks for new stable releases (and for new tools: a GregoireF repository
with the `gregoiref-tap` topic joins on its own), verifies their archives,
writes the formula and the manifests, installs them on every platform, and
only then commits the result to `main`, publishes the catalog and submits
the WinGet manifests. Each night it reinstalls everything and checks the
health of what it serves. See [ARCHITECTURE.md](ARCHITECTURE.md) and the
[roadmap](ROADMAP.md).

Found a problem with an install? [Open an issue](https://github.com/GregoireF/homebrew-tap/issues/new/choose).
A bug in a tool itself belongs to that tool's repository.

## License

The packaging files in this repository are available under the
[MIT](LICENSE-MIT) or [Apache-2.0](LICENSE-APACHE) license, at your option.
Each tool has its own license, listed in its formula.
