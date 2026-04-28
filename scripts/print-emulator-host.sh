#!/usr/bin/env bash
# Print the Mac's LAN IP so you can paste it into the Xcode scheme's
# EMULATOR_HOST env var when running on a tethered iPhone.
#
# Usage:  ./scripts/print-emulator-host.sh
set -euo pipefail

ip=""
for iface in en0 en1 en2; do
    if ip=$(ipconfig getifaddr "$iface" 2>/dev/null) && [ -n "$ip" ]; then
        echo "$iface  $ip"
        break
    fi
done

if [ -z "$ip" ]; then
    echo "No LAN IP found on en0/en1/en2." >&2
    echo "Are you on Wi-Fi? Try:  networksetup -listallhardwareports" >&2
    exit 1
fi

cat <<EOF

Set this in Xcode: Product ▸ Scheme ▸ Edit Scheme… ▸ Run ▸ Arguments ▸
Environment Variables:
    EMULATOR_HOST = $ip
    USE_EMULATOR  = 1

Confirm the Firebase emulators are running with:
    cd ../steward && pnpm emulators
And reachable at  http://$ip:4000  (Emulator UI).
EOF
