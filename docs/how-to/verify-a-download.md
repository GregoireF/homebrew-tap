# Verify a download

Three checks, from the strongest to the simplest. The tap runs all that
apply before it publishes a version; these commands let you repeat them.

## 1. The tool's build provenance (SLSA)

For tools marked **SLSA provenance** in the [catalog](https://gregoiref.github.io/homebrew-tap/):

```sh
gh attestation verify ship_0.1.2_linux_amd64.tar.gz --repo GregoireF/ship-it
```

It checks a Sigstore-signed statement that a GitHub Actions workflow of
`GregoireF/ship-it` built this exact file from that repository.

## 2. The file the tap serves

Every formula, manifest, `flake.nix` and aqua registry the tap publishes
carries its own provenance, signed by the tap's `sync.yml`:

```sh
curl -fsSLO https://raw.githubusercontent.com/GregoireF/homebrew-tap/main/Formula/ship.rb
gh attestation verify ship.rb --repo GregoireF/homebrew-tap
```

A file that fails this was not written by the tap's workflow.

## 3. The checksum

```sh
gh release download v0.1.2 --repo GregoireF/ship-it --pattern 'ship_0.1.2_linux_amd64.tar.gz' --pattern checksums.txt
sha256sum --ignore-missing -c checksums.txt
```

The tap's own record of each SHA-256 is in
[`tools.lock.json`](../../tools.lock.json) and in the
[API](../reference/api.md): `curl -fsSL https://gregoiref.github.io/homebrew-tap/api/v1/tools/ship.json`.
