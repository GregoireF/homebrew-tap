# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

module Tap
  # Parses a sha256sum file: `<hex>  name` (text mode) or `<hex> *name`
  # (binary mode), as GoReleaser and cargo-dist write them.
  module Checksums
    LINE = /\A(?<sum>[0-9a-f]{64}) [ *](?<name>\S.*)\z/

    module_function

    def parse(text)
      text.each_line.with_object({}) do |raw, sums|
        line = raw.chomp
        next if line.strip.empty?

        (match = LINE.match(line)) || raise(Error, "checksums: unexpected line #{line.inspect}")
        name = match[:name]
        raise Error, "checksums: #{name} listed twice" if sums.key?(name)

        sums[name] = match[:sum]
      end
    end
  end
end
