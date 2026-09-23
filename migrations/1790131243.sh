echo "Add the networking commands: speed test, DNS, and sharing the Wi-Fi"

# Nothing to migrate — all of it is new commands and new menu rows, both
# package-owned. Worth naming, because none of it is anywhere you would look.

echo "  omacos network speedtest    macOS's own networkQuality, no account"
echo "  omacos network dns          Cloudflare, Google, Quad9, or back to DHCP"
echo "  omacos network qr <ssid>    a QR code to get a phone onto the Wi-Fi"
echo "  also under: omacos menu > System > Network"

# The SSID being unreadable is surprising enough to say once, up front, rather
# than let it be discovered as an error message.
if ipconfig getsummary en0 2>/dev/null | grep -q '<redacted>'; then
  echo "  note: macOS will not tell a terminal your Wi-Fi name — it is location"
  echo "        data since macOS 14 — so qr and password take it as an argument"
fi
