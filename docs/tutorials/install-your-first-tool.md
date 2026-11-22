# Install your first tool

In ten minutes you install `kiwa` from this tap, check that it is the build
its authors published, and upgrade it later. Pick the section of your
system; each one ends with the same check.

## 1. Install

### macOS or Linux, with Homebrew

```sh
brew install gregoiref/tap/kiwa
```

Naming the tap in full trusts only this formula (Homebrew 6 and later
refuse to load a non-official tap you have not trusted). To use short names,
tap and trust once:

```sh
brew tap gregoiref/tap
brew trust --formula gregoiref/tap/kiwa   # or the whole tap: brew trust gregoiref/tap
brew install kiwa
```

In a `Brewfile`:

```ruby
tap "gregoiref/tap", trusted: { formulae: ["kiwa", "ship"] }
brew "gregoiref/tap/kiwa"
```

### Windows, with Scoop

```powershell
scoop bucket add gregoiref https://github.com/GregoireF/homebrew-tap
scoop install gregoiref/kiwa
```

### Without a package manager

```sh
curl -fsSL https://gregoiref.github.io/homebrew-tap/install.sh | sh -s -- kiwa
```

It installs into `~/.local/bin` and prints each check it makes:

```text
Downloading https://github.com/GregoireF/kiwa/releases/download/v0.1.0/kiwa-x86_64-unknown-linux-gnu.tar.xz
SHA-256 verified
SLSA provenance verified (signed by a workflow of GregoireF/kiwa)
Installed /home/you/.local/bin/kiwa
Installed /home/you/.local/bin/kw
```

The provenance line appears when the [GitHub CLI](https://cli.github.com) is
installed and logged in; add `--require-provenance` to refuse installing
without it.

## 2. Check it runs

```sh
kiwa --version
```

```text
kiwa 0.1.0
```

## 3. Check where it comes from

The tap verified the archive before publishing it. You can check it too:

```sh
gh release download v0.1.0 --repo GregoireF/kiwa --pattern 'kiwa-x86_64-unknown-linux-gnu.tar.xz'
gh attestation verify kiwa-x86_64-unknown-linux-gnu.tar.xz --repo GregoireF/kiwa
```

`Verification succeeded!` means the archive was built by a GitHub Actions
workflow of `GregoireF/kiwa`, from that repository's source. More in
[Verify a download](../how-to/verify-a-download.md).

## 4. Upgrade later

```sh
brew upgrade kiwa          # Homebrew
scoop update kiwa          # Scoop
```

A new kiwa release reaches the tap within 30 minutes, after the same
checks. The [catalog](https://gregoiref.github.io/homebrew-tap/) and its
[Atom feed](https://gregoiref.github.io/homebrew-tap/feed.xml) list what is
served.

## Next

- Other ways in (WinGet, Nix, aqua, mise): [Package managers](../explanation/package-managers.md)
- Something failed: [open an issue](https://github.com/GregoireF/homebrew-tap/issues/new/choose)
