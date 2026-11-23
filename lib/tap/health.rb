# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "time"

module Tap
  # Nightly checks of what the tap serves, beyond "does it install":
  #   - a tool in tools.yml that was never published;
  #   - a tool whose last release is more than a year old;
  #   - an archive of a `verify: attestation` tool whose provenance GitHub no
  #     longer holds (deleted attestation, rewritten release);
  #   - a `verify: checksum` tool whose releases now carry a provenance: raise
  #     it to `attestation` in tools.yml.
  # Uses the attestations API by digest: nothing is downloaded.
  class Health
    STALE_DAYS = 365

    def initialize(github:, now: Time.now.utc)
      @github = github
      @now = now
    end

    # A list of findings, empty when everything is fine.
    def run(tools, lock)
      tools.flat_map { |tool| check(tool, lock[tool.name]) }
    end

    def self.report(findings)
      return "Everything the tap serves is healthy.\n" if findings.empty?

      findings.map { |f| "- #{f}\n" }.join
    end

    def stale?(release)
      return false if release.published.nil?

      (@now - Time.iso8601(release.published)) / 86_400 > STALE_DAYS
    end

    private

    def check(tool, release)
      return ["`#{tool.name}`: in tools.yml but never published (no stable release, or sync failing)"] if release.nil?

      findings = []
      if tool.pin
        findings << "`#{tool.name}` is pinned to #{tool.pin}: run `bin/tap unpin #{tool.name}` " \
                    "once a fixed release is out"
      end
      if stale?(release)
        date = release.published[0, 10]
        findings << "`#{tool.name}`: last release #{release.version} on #{date}, " \
                    "more than #{STALE_DAYS} days ago"
      end
      if tool.verify == "attestation"
        missing = PLATFORMS.reject { |p| @github.attested?(tool.repo, release.sha256(p)) }
        unless missing.empty?
          findings << "`#{tool.name}` #{release.version}: no provenance any more for #{missing.join(", ")}"
        end
      elsif @github.attested?(tool.repo, release.sha256("linux_amd64"))
        findings << "`#{tool.name}` #{release.version} carries a build provenance now: " \
                    "set `verify: attestation` in tools.yml"
      end
      findings
    end
  end
end
