# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

# The generator of GregoireF/homebrew-tap (ARCHITECTURE.md).

# Model: tools.yml, the lock, what targets render from.
require_relative "tap/config"
require_relative "tap/lock"
require_relative "tap/catalog"

# Talking to releases.
require_relative "tap/checksums"
require_relative "tap/github"
require_relative "tap/verifier"
require_relative "tap/sync"
require_relative "tap/onboard"
require_relative "tap/health"
require_relative "tap/commit_lint"

# Outputs: one module per package manager or publication.
require_relative "tap/targets"
Dir[File.join(__dir__, "tap/targets/*.rb")].each { |f| require f }

# bin/tap.
require_relative "tap/workspace"
require_relative "tap/commands"
Dir[File.join(__dir__, "tap/commands/*.rb")].each { |f| require f }
require_relative "tap/cli"
