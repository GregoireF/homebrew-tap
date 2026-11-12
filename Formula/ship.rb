# typed: false
# frozen_string_literal: true

# Written by the release workflow of GregoireF/ship-it (scripts/homebrew-formula.sh);
# do not edit by hand, the next release replaces it.
class Ship < Formula
  desc "You write the code, ship handles git and GitHub"
  homepage "https://github.com/GregoireF/ship-it"
  version "0.1.2"
  license "Apache-2.0"

  on_macos do
    on_intel do
      url "https://github.com/GregoireF/ship-it/releases/download/v0.1.2/ship_0.1.2_darwin_amd64.tar.gz"
      sha256 "c365f5db275b2b4baa5859e8e67152ab8cd450c39a18ef0b0eba89c288372587"
    end
    on_arm do
      url "https://github.com/GregoireF/ship-it/releases/download/v0.1.2/ship_0.1.2_darwin_arm64.tar.gz"
      sha256 "63792d228e99238e75fe7b41e4aace755683e12766baa93ae7012438416eb186"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/GregoireF/ship-it/releases/download/v0.1.2/ship_0.1.2_linux_amd64.tar.gz"
      sha256 "e792dbb722ec1b8bf72a8c33e1d8e1d2f4ff37a0d1d4832d1357e6934275bd42"
    end
    on_arm do
      url "https://github.com/GregoireF/ship-it/releases/download/v0.1.2/ship_0.1.2_linux_arm64.tar.gz"
      sha256 "2b9dd435c9fd2f18d6fcff1056f3bbcba9a0d92c27009aa55c73ea1d57f9daaa"
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
