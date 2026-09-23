echo "Offer Touch ID for sudo, the way Omarchy offers a fingerprint"

# Nothing is changed here. Writing to /etc/pam.d needs your password, and a
# migration is the wrong place to ask for it — this only says the command
# exists, and only on a Mac that actually has the sensor.

if [[ -f /etc/pam.d/sudo_local ]] && grep -q pam_tid.so /etc/pam.d/sudo_local 2>/dev/null; then
  exit 0   # already on
fi

# Captured rather than piped into grep -q: with pipefail, grep exiting early
# SIGPIPEs ioreg and the test silently inverts.
biometrics=$(ioreg -c AppleBiometricSensor 2>/dev/null) || biometrics=""
if [[ $biometrics == *AppleBiometricSensor* ]]; then
  echo "  this Mac has Touch ID, and sudo is still asking you to type a password"
  echo "  turn it on with: omacos setup touchid"
  echo "  it also works inside tmux, which needs one extra module — it installs that too"
fi
