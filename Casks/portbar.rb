cask "portbar" do
  version "0.1.0"
  sha256 "cf91103f27c6d0266c106605ce587f1fec702f50e5d3021c18f79cc34ffea4a4"

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
