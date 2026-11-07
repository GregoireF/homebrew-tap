# typed: false
# frozen_string_literal: true

# Written by the release workflow of GregoireF/ship-it (scripts/homebrew-formula.sh);
# do not edit by hand, the next release replaces it.
class Ship < Formula
  desc "You write the code, ship handles git and GitHub"
  homepage "https://github.com/GregoireF/ship-it"
  version "0.1.0"
  license "Apache-2.0"

  on_macos do
    on_intel do
      url "https://github.com/GregoireF/ship-it/releases/download/v0.1.0/ship_0.1.0_darwin_amd64.tar.gz"
      sha256 "8500cfe34945a971157ecb64bb1888f34959bd0c0c473bb47d32321e7be3d099"
    end
    on_arm do
      url "https://github.com/GregoireF/ship-it/releases/download/v0.1.0/ship_0.1.0_darwin_arm64.tar.gz"
      sha256 "a3ca6b670ee12fb4246951480632478aa1fdb3e9706d2b6ee151332206021127"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/GregoireF/ship-it/releases/download/v0.1.0/ship_0.1.0_linux_amd64.tar.gz"
      sha256 "fe4de00d92a73e1664001a3eb90982dd6a28e5a76c7b20777382d936d128653f"
    end
    on_arm do
      url "https://github.com/GregoireF/ship-it/releases/download/v0.1.0/ship_0.1.0_linux_arm64.tar.gz"
      sha256 "41802ab4487a49b6aa1b0679c98c52026cc3e03f31ac98f5b5b6cf91e244dddb"
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
