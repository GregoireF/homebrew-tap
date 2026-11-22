# Adding a tool

A tool can join the tap once its repository publishes **stable GitHub
releases** with:

- one archive per platform: macOS and Linux (x86_64, arm64) as `.tar.gz` or
  `.tar.xz`, Windows (x64, arm64) as `.zip`, with the binaries at the top
  level of each archive;
- a checksums file in sha256sum format (`checksums.txt` from GoReleaser,
  `sha256.sum` from cargo-dist);
- ideally, a SLSA build provenance for every archive
  (`actions/attest-build-provenance`, or `github-attestations = true` in
  cargo-dist). Without one, the tool can only use `verify: checksum`.

The tool's repository needs **no secret and no job** for the tap.

## Without doing anything here

Add the topic **`gregoiref-tap`** to the repository. Within 30 minutes
`sync.yml` runs `bin/tap discover --add`: it infers the entry from the latest
release (archives, checksums file, binary, licence, verification level,
WinGet id), then the usual pipeline verifies, install-tests and publishes it.
A repository whose entry cannot be inferred is skipped with a message in the
sync log; write its entry by hand.

## By hand

```sh
bin/tap add GregoireF/<repo>   # appends the inferred entry to tools.yml
# review it: a second binary, `test` arguments, `completions`, `caveats`
bin/tap sync                   # downloads, verifies, writes the files
rake                           # tests + bin/tap check
```

Or push only the `tools.yml` change: the next scheduled sync does the rest.
The keys are documented at the top of [`tools.yml`](../tools.yml) and in
[`schema/tools.schema.json`](../schema/tools.schema.json), which editors
with the YAML language server use for completion.

## Check a formula locally on Windows

```sh
docker run --rm -v "$PWD:/src:ro" homebrew/brew bash -c '
  cp -r /src /tmp/tap && cd /tmp/tap && chmod -R go-w . &&
  git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm t &&
  brew tap gregoiref/tap /tmp/tap &&
  brew audit --strict --online --tap gregoiref/tap &&
  brew install gregoiref/tap/<tool> && brew test gregoiref/tap/<tool>'
winget validate --manifest winget/manifests/g/GregoireF/<tool>/<version>
```
