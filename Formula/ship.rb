# typed: false
# frozen_string_literal: true

# Written by the release workflow of GregoireF/ship-it (scripts/homebrew-formula.sh);
# do not edit by hand, the next release replaces it.
class Ship < Formula
  desc "You write the code, ship handles git and GitHub"
  homepage "https://github.com/GregoireF/ship-it"
  version "0.1.1"
  license "Apache-2.0"

  on_macos do
    on_intel do
      url "https://github.com/GregoireF/ship-it/releases/download/v0.1.1/ship_0.1.1_darwin_amd64.tar.gz"
      sha256 "d65e4d168d5bb25ccbaf3bd0b2463e5d39c1867bc94e4dd8cc977deec2a2ff7d"
    end
    on_arm do
      url "https://github.com/GregoireF/ship-it/releases/download/v0.1.1/ship_0.1.1_darwin_arm64.tar.gz"
      sha256 "aa05e829ac6d1de1c368bb73ecfe90c787f921ffd7a8b8026e480e1e3403e470"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/GregoireF/ship-it/releases/download/v0.1.1/ship_0.1.1_linux_amd64.tar.gz"
      sha256 "c43ebb48de1ec53b8deff23bee328c796d9bf289e53ffe9baed883443744536c"
    end
    on_arm do
      url "https://github.com/GregoireF/ship-it/releases/download/v0.1.1/ship_0.1.1_linux_arm64.tar.gz"
      sha256 "f1c8743b65591a3603bd6fb572f8718dc5ebd7f858ab2109832c87eb87bb6fb6"
    end
  end

  def install
    bin.install "ship"
  end

  def caveats
    <<~EOS
      ship needs git 2.43 or later. Run `ship doctor` to check your setup.
    EOS
  end

  test do
    system "#{bin}/ship", "version"
  end
end
