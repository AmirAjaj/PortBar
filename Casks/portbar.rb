cask "portbar" do
  version "0.2.0"
  sha256 "179dda3a9e327c35a2dc888fe773c96b19a104a610ace67f2f95fe26e0f25e9a"

  url "https://github.com/AmirAjaj/PortBar/releases/download/v#{version}/PortBar.zip"
  name "PortBar"
  desc "Menu bar app to see and kill the dev servers listening on your ports"
  homepage "https://github.com/AmirAjaj/PortBar"

  depends_on macos: ">= :sonoma"

  app "PortBar.app"

  zap trash: [
    "~/Library/Preferences/com.amirajaj.portbar.plist",
  ]

  caveats <<~EOS
    PortBar is ad-hoc signed (not yet notarized), so macOS Gatekeeper may block
    the first launch. If it does, either:

      • System Settings → Privacy & Security → "Open Anyway", or
      • run once:  xattr -dr com.apple.quarantine "/Applications/PortBar.app"
  EOS
end
