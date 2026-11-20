# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "json"

module Tap
  # The released archives of one tool version: what tools.lock.json records.
  # assets: { platform => { "name" => ..., "sha256" => ... } }
  # published: the release's publication time (ISO 8601), nil if unknown.
  Release = Data.define(:tag, :version, :verified, :assets, :published) do
    define_method(:url) do |tool, platform|
      "https://github.com/#{tool.repo}/releases/download/#{tag}/#{assets.fetch(platform).fetch("name")}"
    end

    define_method(:sha256) do |platform|
      assets.fetch(platform).fetch("sha256")
    end

    define_method(:to_lock) do
      out = { "tag" => tag, "version" => version, "verified" => verified }
      out["published"] = published if published
      out.merge("assets" => assets)
    end
  end.freeze

  # tools.lock.json: the version of every tool the tap serves, with the name
  # and SHA-256 of each archive. Written by `bin/tap sync` only.
  class Lock
    def self.load(path)
      return new(path, {}) unless File.exist?(path)

      data = JSON.parse(File.binread(path))
      releases = data.fetch("tools", {}).transform_values do |r|
        Release.new(tag: r.fetch("tag"), version: r.fetch("version"), verified: r.fetch("verified"),
                    assets: r.fetch("assets"), published: r["published"])
      end
      new(path, releases)
    end

    def initialize(path, releases)
      @path = path
      @releases = releases
    end

    def [](name) = @releases[name]

    def []=(name, release)
      @releases[name] = release
    end

    def names = @releases.keys

    def to_json(*)
      tools = @releases.sort.to_h.transform_values(&:to_lock)
      "#{JSON.pretty_generate({ "tools" => tools })}\n"
    end

    def save = File.binwrite(@path, to_json)
  end
end
