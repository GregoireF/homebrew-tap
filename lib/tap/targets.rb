# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "erb"

module Tap
  # A target turns the catalog into the files of one package manager or
  # publication. Every target is a module with:
  #
  #   files(catalog) -> { relative path => content }   pure, deterministic
  #   GLOBS                                             paths it owns, so
  #                                                     strays get removed
  #
  # Repository targets are committed by sync (and checked for drift); site
  # targets are written to the Pages artifact only. Adding a package manager
  # is adding one file under targets/ and one name here.
  module Targets
    ROOT = File.expand_path("../..", __dir__).freeze

    module_function

    def repository = [Homebrew, Scoop, Winget, Nix, Aqua, Readme, Docs]

    def site = [Pages, Api, Badges, Installer]

    def files(targets, catalog)
      targets.each_with_object({}) { |target, out| out.merge!(target.files(catalog)) }
    end

    def globs(targets) = targets.flat_map { |target| target::GLOBS }

    # A template under templates/, compiled once.
    def template(rel)
      ERB.new(File.binread(File.join(ROOT, "templates", rel)).force_encoding(Encoding::UTF_8), trim_mode: "-")
    end
  end
end
