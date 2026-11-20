# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "fileutils"

require_relative "tap/config"
require_relative "tap/lock"
require_relative "tap/checksums"
require_relative "tap/github"
require_relative "tap/verifier"
require_relative "tap/sync"
require_relative "tap/winget"
require_relative "tap/render"
require_relative "tap/onboard"
require_relative "tap/health"
require_relative "tap/site"
require_relative "tap/commit_lint"
require_relative "tap/cli"
