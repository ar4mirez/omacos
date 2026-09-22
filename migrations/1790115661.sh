echo "Add WhatsApp and Telegram as apps of their own"

# The catalog now carries WhatsApp itself, so the web app that used to hold
# that name is "WhatsApp Web" — the suffix ChatGPT Web and Zoom Web already
# use. A web app's bundle is named after its label, so one installed before
# this release still sits at ~/Applications/WhatsApp.app, where it would both
# duplicate the cask's row in the menus and answer "installed" for a bundle
# that is no longer the one the catalog describes.
#
# Only a bundle carrying the omacos marker is touched; the cask installs into
# /Applications, which bundle_path never looks at.
# shellcheck source=/dev/null
. "$OMACOS_PATH/default/lib/bundles.sh"

old=$(bundle_path "WhatsApp")
if [[ -d $old ]] && bundle_kind "$old" >/dev/null 2>&1; then
  # Rebuild from the URL the bundle records rather than the catalog's, so a
  # web app you pointed somewhere else keeps pointing there.
  url=$(bundle_url "WhatsApp" 2>/dev/null || true)
  [[ -n $url ]] || url="https://web.whatsapp.com/"
  if omacos-webapp-install "WhatsApp Web" "$url" >/dev/null 2>&1; then
    bundle_remove "WhatsApp" webapp >/dev/null 2>&1 || true
    echo "  your WhatsApp web app is now WhatsApp Web"
  else
    echo "  could not rebuild your WhatsApp web app under its new name"
    echo "  do it by hand with: omacos install app webapp.whatsapp"
  fi
fi

echo "  omacos install app service.whatsapp service.telegram"
