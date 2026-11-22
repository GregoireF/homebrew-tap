#!/bin/sh
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# End-to-end test of aqua/registry.yaml with aqua itself: installs every tool
# of the registry at the version the lock serves, then runs it. Needs aqua,
# ruby, and the repository as the current directory:
#
#   sh test/aqua.sh
set -eu

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM

# name@version per tool, from the lock: aqua checks the release's checksums.
ruby -rjson -e '
  lock = JSON.parse(File.read("tools.lock.json"))["tools"]
  require "yaml"
  YAML.safe_load(File.read("tools.yml"))["tools"].each do |name, t|
    r = lock[name] or next
    puts "#{t["repo"]}@#{r["tag"]} #{t["binaries"].first} #{t["test"].join(" ")}"
  end' >"$work/tools"

{
  printf 'registries:\n  - type: local\n    name: gregoiref\n    path: %s/aqua/registry.yaml\npackages:\n' "$PWD"
  while read -r package _; do printf '  - name: %s\n    registry: gregoiref\n' "$package"; done <"$work/tools"
} >"$work/aqua.yaml"
printf -- '---\nregistries:\n  - type: local\n    name: gregoiref\n    path: %s/aqua/registry.yaml\npackages:\n  - registry: gregoiref\n' \
  "$PWD" >"$work/aqua-policy.yaml"

export AQUA_GLOBAL_CONFIG="$work/aqua.yaml" AQUA_POLICY_CONFIG="$work/aqua-policy.yaml"
export AQUA_ROOT_DIR="$work/root" PATH="$work/root/bin:$PATH"
aqua install --all

while read -r _ binary args; do
  # shellcheck disable=SC2086 # the test arguments are words
  "$binary" $args >/dev/null || { printf 'FAIL: %s does not run\n' "$binary" >&2; exit 1; }
  printf 'runs through aqua: %s\n' "$binary"
done <"$work/tools"
printf 'aqua: all checks passed\n'
