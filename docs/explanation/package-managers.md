# Package managers

One verified lock, seven ways in. Every one installs the same archives,
pinned by the same SHA-256.

| Way in | Systems | Command | Generated file | Tested by |
| --- | --- | --- | --- | --- |
| Homebrew | macOS, Linux | `brew install gregoiref/tap/kiwa` | `Formula/*.rb` | brew test on 5 runners |
| Scoop | Windows | `scoop install gregoiref/kiwa` | `bucket/*.json` | 2 runners |
| WinGet | Windows | `winget install --id GregoireF.kiwa --exact` | `winget/manifests/` | `winget validate` |
| Nix | macOS, Linux | `nix run github:GregoireF/homebrew-tap#kiwa` | `flake.nix` | nix run on 2 runners |
| aqua | macOS, Linux, Windows | `aqua i`, with the registry below in `aqua.yaml` | `aqua/registry.yaml` | aqua install on 2 runners |
| mise | macOS, Linux, Windows | `mise use github:GregoireF/kiwa` | none (reads GitHub releases) | not tested here |
| install.sh | macOS, Linux | `curl -fsSL …/install.sh \| sh -s -- kiwa` | site `install.sh` | 3 systems, Alpine included |

## Homebrew naming

homebrew-core already has an `addlicense` formula, for
[google/addlicense](https://github.com/google/addlicense). Following
[Homebrew's guidance](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap#naming-your-formulae-to-avoid-clashes),
this tap's formula is `gregoiref-addlicense`; it installs the `addlicense`
command and declares the conflict
([ADR-0007](../adr/0007-gregoiref-addlicense.md)). `formula_renames.json`
keeps the old name working.

## aqua

Add the registry to `aqua.yaml`, and allow it in your aqua policy:

```yaml
registries:
  - type: github_content
    name: gregoiref
    repo_owner: GregoireF
    repo_name: homebrew-tap
    ref: main
    path: aqua/registry.yaml
packages:
  - name: GregoireF/kiwa@v0.1.0
    registry: gregoiref
```

aqua checks each download against the release's checksums file.

## Nix

```sh
nix run github:GregoireF/homebrew-tap#ship -- version
nix profile install github:GregoireF/homebrew-tap#kiwa
```

The flake pins nixpkgs in `flake.lock`; Linux builds linked against glibc
are patched with `autoPatchelfHook`.

## For other tools: the API

`https://gregoiref.github.io/homebrew-tap/api/v1/tools/<tool>.json` has the
version, every archive's URL and SHA-256, and the install command of each
way in ([reference](../reference/api.md)).
