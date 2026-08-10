#!/usr/bin/env bash
#
# provision-device.sh — post-flash configuration for a Parkva Jetson Xavier NX device.
#
# Given a balena device UUID and device number, this script performs the manual
# post-flash steps automatically via the balena CLI:
#   1. Rename the device to zzz-p400<number>-xnx-eth0.
#   2. Host OS: remount read-write, add the parkvapatrol.com /etc/hosts entry, and
#      write the four NetworkManager connection files (cellular / shared-ethernet /
#      poe-0 / poe-1).
#   3. Set the five MASKCAM_* device variables (scoped to the lpr-scan service).
#   4. Shut down the device (changes take effect on next boot).
#
# Usage:
#   ./scripts/provision-device.sh <device-uuid> <device-number> [--dry-run]
#
# Prerequisites: the balena CLI installed and logged in (`balena login`), and the
# target device online.

set -euo pipefail

# ---------------------------------------------------------------------------
# Config — edit these constants as needed.
# ---------------------------------------------------------------------------
HOSTS_ENTRY="10.42.0.1	parkvapatrol.com"

# Device name is built as: ${NAME_PREFIX}${NUMBER}${NAME_SUFFIX}
# e.g. number 1234 -> zzz-p4001234-xnx-eth0
NAME_PREFIX="zzz-p400"
NAME_SUFFIX="-xnx-eth0"

LPR_SERVICE="lpr-scan"

MASKCAM_CLIENT_ID="test.parkva"
MASKCAM_PERMIT_SYSTEM="LotMemory"
MASKCAM_TOWER_SYSTEM="LotMemory"
MASKCAM_DEVICE_PASSWORD="12345"
MASKCAM_PROCESSOR_TYPE="xaviernx"

# POE static addressing (address/prefix,gateway) for the two PoE NICs.
POE0_ADDRESS="192.168.0.50/24,192.168.0.1"
POE1_ADDRESS="192.168.1.50/24,192.168.1.1"

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
DRY_RUN=0
UUID=""
NUMBER=""

usage() {
	cat <<EOF
Usage: $(basename "$0") <device-uuid> <device-number> [--dry-run]

  <device-uuid>     balena device UUID to provision.
  <device-number>   device number used to rename it to ${NAME_PREFIX}<number>${NAME_SUFFIX}.
  --dry-run         Print every balena command and the host OS snippet without
                    executing anything.
EOF
}

positionals=()
for arg in "$@"; do
	case "$arg" in
		--dry-run) DRY_RUN=1 ;;
		-h|--help) usage; exit 0 ;;
		-*)
			echo "Error: unknown option '$arg'" >&2
			usage >&2
			exit 1
			;;
		*)
			positionals+=("$arg")
			;;
	esac
done

if [[ "${#positionals[@]}" -lt 2 ]]; then
	echo "Error: device UUID and device number are both required." >&2
	usage >&2
	exit 1
fi
if [[ "${#positionals[@]}" -gt 2 ]]; then
	echo "Error: unexpected extra argument '${positionals[2]}'" >&2
	usage >&2
	exit 1
fi
UUID="${positionals[0]}"
NUMBER="${positionals[1]}"
DEVICE_NAME="${NAME_PREFIX}${NUMBER}${NAME_SUFFIX}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }

# Run a command, or just print it in dry-run mode.
run() {
	if [[ "$DRY_RUN" -eq 1 ]]; then
		printf '    [dry-run] %s\n' "$*"
	else
		"$@"
	fi
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
log "Preflight checks"

if ! command -v balena >/dev/null 2>&1; then
	echo "Error: the balena CLI is not installed or not on PATH." >&2
	echo "Install it from https://github.com/balena-io/balena-cli" >&2
	exit 1
fi
info "balena CLI found: $(command -v balena)"

if [[ "$DRY_RUN" -eq 1 ]]; then
	info "Dry-run mode: skipping login/online checks."
else
	if ! balena whoami >/dev/null 2>&1; then
		echo "Error: not logged in to balena. Run 'balena login' first." >&2
		exit 1
	fi
	info "Logged in as: $(balena whoami | awk -F': ' '/USERNAME|username/{print $2; exit}')"

	# Confirm the device exists and is online (host OS SSH + reboot need it).
	if ! device_info="$(balena device "$UUID" 2>/dev/null)"; then
		echo "Error: device '$UUID' not found (check the UUID and your login)." >&2
		exit 1
	fi
	if ! grep -qiE '^\s*STATUS:\s*.*(idle|running|online)|is online|IS ONLINE:\s*true' <<<"$device_info"; then
		echo "Error: device '$UUID' does not appear to be online." >&2
		echo "The host OS configuration and reboot require the device to be online." >&2
		echo "Device status output:" >&2
		echo "$device_info" | grep -iE 'STATUS|ONLINE' >&2 || true
		exit 1
	fi
	info "Device '$UUID' is online."
fi

# ---------------------------------------------------------------------------
# Rename the device to zzz-p400<number>-xnx-eth0.
# ---------------------------------------------------------------------------
log "Renaming device $UUID to $DEVICE_NAME"
run balena device rename "$UUID" "$DEVICE_NAME"

# ---------------------------------------------------------------------------
# Host OS configuration snippet (idempotent).
#
# Piped to `balena device ssh <uuid>` (no service -> host OS shell).
# Single-quoted heredoc so the LOCAL shell does not expand anything; values that
# vary are injected as shell variables assigned at the top of the remote snippet.
# ---------------------------------------------------------------------------
REMOTE_SCRIPT="$(cat <<REMOTE_HEADER
HOSTS_ENTRY='${HOSTS_ENTRY}'
POE0_ADDRESS='${POE0_ADDRESS}'
POE1_ADDRESS='${POE1_ADDRESS}'
REMOTE_HEADER
)"
REMOTE_SCRIPT+=$'\n'
REMOTE_SCRIPT+="$(cat <<'REMOTE_BODY'
set -e

echo "  [host] remounting / read-write"
mount -o remount,rw /

NM_DIR=/etc/NetworkManager/system-connections
mkdir -p "$NM_DIR"

# /etc/hosts: add the parkvapatrol.com entry only if not already present.
if grep -q "parkvapatrol.com" /etc/hosts; then
	echo "  [host] /etc/hosts already contains parkvapatrol.com, leaving it"
else
	echo "  [host] adding parkvapatrol.com to /etc/hosts"
	printf '%s\n' "$HOSTS_ENTRY" >> /etc/hosts
fi

# Write a NetworkManager connection file only if it does not already exist,
# then lock it down to 0600 (NM ignores group/world-readable connection files).
write_conn() {
	local name="$1" content="$2"
	local path="$NM_DIR/$name"
	if [ -e "$path" ]; then
		echo "  [host] $path exists, leaving it"
	else
		echo "  [host] writing $path"
		printf '%s\n' "$content" > "$path"
	fi
	chown root:root "$path"
	chmod 600 "$path"
}

write_conn cdc-wdm0 '[connection]
id=cellular
type=gsm
autoconnect=true
autoconnect-priority=100

[gsm]
apn=Fast.t-mobile.com
allow-roaming=yes

[serial]
baud=115200

[ipv4]
method=auto

[ipv6]
addr-gen-mode=stable-privacy
method=auto'

write_conn eth0 '[connection]
id=shared-ethernet
type=ethernet
interface-name=eth0

[ethernet]

[ipv4]
method=shared

[ipv6]
method=shared'

write_conn enP5p4s0 "[connection]
id=poe-0
type=ethernet
interface-name=enP5p4s0

[ethernet]
mac-address-blacklist=

[ipv4]
address1=$POE0_ADDRESS
dns-search=
method=manual
never-default=true

[ipv6]
addr-gen-mode=stable-privacy
method=disabled"

write_conn enP5p5s0 "[connection]
id=poe-1
type=ethernet
interface-name=enP5p5s0

[ethernet]
mac-address-blacklist=

[ipv4]
address1=$POE1_ADDRESS
dns-search=
method=manual
never-default=true

[ipv6]
addr-gen-mode=stable-privacy
method=disabled"

# Note: we intentionally do NOT run `nmcli connection reload` here. Reloading over
# the same balena SSH tunnel can stall the session, and the final reboot loads the
# new connections cleanly anyway.
echo "  [host] host OS configuration complete (reboot will load the new connections)"
REMOTE_BODY
)"

log "Configuring host OS (hosts + NetworkManager connections) on $UUID"
if [[ "$DRY_RUN" -eq 1 ]]; then
	info "[dry-run] balena device ssh $UUID  <<'the following snippet'"
	printf '%s\n' "$REMOTE_SCRIPT" | sed 's/^/    | /'
else
	# Trailing `exit` makes the remote (interactive) shell close itself. Without it,
	# `balena device ssh` does not propagate stdin EOF and the session hangs after
	# the last command instead of returning.
	#
	# The host OS SSH goes through the balena gateway, which caps auth attempts. When
	# your ssh-agent holds several keys, the gateway can intermittently reject before
	# the accepted key is offered ("Permission denied (publickey)"). Retry a few times
	# so a transient auth miss does not abort provisioning; the remote script is
	# idempotent, so re-running it is safe.
	ssh_attempt=1
	ssh_max_attempts=4
	until printf '%s\nexit 0\n' "$REMOTE_SCRIPT" | balena device ssh "$UUID"; do
		if [[ "$ssh_attempt" -ge "$ssh_max_attempts" ]]; then
			echo "Error: host OS SSH failed after $ssh_max_attempts attempts." >&2
			echo "Check 'ssh-add -l' and your balenaCloud SSH keys, then re-run." >&2
			exit 1
		fi
		echo "  SSH attempt $ssh_attempt failed; retrying in 5s..." >&2
		ssh_attempt=$((ssh_attempt + 1))
		sleep 5
	done
fi

# ---------------------------------------------------------------------------
# Device variables (device-level, scoped to the lpr-scan service).
# `balena env set` is an upsert: it creates or overrides the value.
# ---------------------------------------------------------------------------
log "Setting MASKCAM_* device variables (service: $LPR_SERVICE)"

set_env() {
	local name="$1" value="$2"
	info "$name = $value"
	run balena env set "$name" "$value" -d "$UUID" -s "$LPR_SERVICE"
}

set_env MASKCAM_CLIENT_ID       "$MASKCAM_CLIENT_ID"
set_env MASKCAM_PERMIT_SYSTEM   "$MASKCAM_PERMIT_SYSTEM"
set_env MASKCAM_TOWER_SYSTEM    "$MASKCAM_TOWER_SYSTEM"
set_env MASKCAM_DEVICE_PASSWORD "$MASKCAM_DEVICE_PASSWORD"
set_env MASKCAM_PROCESSOR_TYPE  "$MASKCAM_PROCESSOR_TYPE"

# ---------------------------------------------------------------------------
# Shut down the device. The new NetworkManager connections and variables take
# effect on the next boot; shutting down lets the operator unplug and move on to
# the next device.
# ---------------------------------------------------------------------------
log "Shutting down device $UUID"
run balena device shutdown "$UUID"

log "Done."
info "Device $UUID ($DEVICE_NAME) has been provisioned and is shutting down."
info "Safe to unplug once it powers off; the new config loads on next boot."
