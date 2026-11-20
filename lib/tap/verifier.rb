# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "open3"

module Tap
  # Checks the SLSA build provenance of a downloaded archive with
  # `gh attestation verify`: the attestation must be signed (Sigstore) by a
  # GitHub Actions workflow of the tool's own repository.
  class Verifier
    # command: how to run the GitHub CLI (tests pass a stand-in).
    def initialize(command: ["gh"])
      @command = command
    end

    # Raises unless `path` carries a valid provenance from `repo`.
    def check_attestation(path, repo)
      out, status = Open3.capture2e(*@command, "attestation", "verify", path, "--repo", repo)
      return if status.success?

      raise Error, "#{File.basename(path)}: no valid provenance from #{repo}\n#{out}"
    end
  end
end
