# Graphical installer for the live medium.
#
# The script shows the eligible disks, asks for the login password, and runs
# nixos-install-tui with the same eligibility and label checks the console
# installer uses. Presentation and the reboot prompt live here; disk handling
# stays in install.py.

set -euo pipefail

# The live session runs as a normal user. Resolve the NixOS sudo wrapper and
# the system tools before the store PATH that writeShellApplication provides.
PATH="/run/wrappers/bin:/run/current-system/sw/bin:$PATH"

installer=${NIXOS_INSTALLER:?NIXOS_INSTALLER is not set}
live_user=${NIXOS_LIVE_USER:?NIXOS_LIVE_USER is not set}
distro_name=${NIXOS_DISTRO_NAME:?NIXOS_DISTRO_NAME is not set}

password_file=$(mktemp)
log_file=$(mktemp)
chmod 600 "$password_file" "$log_file"
trap 'rm -f "$password_file" "$log_file"' EXIT

# Ask the installer for the eligible disks. The list excludes read-only disks,
# the live medium, disks below 16 GiB, and USB transports.
if ! disks_json=$("$installer" --list-disks 2>"$log_file"); then
  zenity --error \
    --title="Cannot list disks" \
    --text="The installer could not list the disks. Run 'sudo nixos-install-tui' in a terminal to use the console flow." \
    --width=500
  exit 1
fi

disk_count=$(jq 'length' <<<"$disks_json")
if [ "$disk_count" -eq 0 ]; then
  zenity --error \
    --title="No target disk" \
    --text="No whole disk meets the installer requirements: UEFI boot, at least 16 GiB, internal, and not the live medium." \
    --width=500
  exit 1
fi

# One disk needs no selection dialog. Several disks use one list so the model
# and size stay visible while the operator chooses.
if [ "$disk_count" -eq 1 ]; then
  disk=$(jq -r '.[0].name' <<<"$disks_json")
  size=$(jq -r '.[0].size_human' <<<"$disks_json")
  model=$(jq -r '.[0].model // "unknown"' <<<"$disks_json")
else
  mapfile -t rows < <(
    jq -r '.[] | [.name, .size_human, ((.model // "unknown") | gsub("\\|"; "/")), (.tran // "")] | @tsv' <<<"$disks_json" \
      | tr '\t' '|'
  )
  selection=$(zenity --list \
    --title="Select the target disk" \
    --text="Choose the disk to erase and install ${distro_name} on." \
    --column="Disk" \
    --column="Size" \
    --column="Model" \
    --column="Transport" \
    --print-column=1 \
    --width=800 \
    --height=400 \
    "${rows[@]}") || exit 0
  disk=$selection
  size=$(jq -r --arg disk "$disk" '.[] | select(.name == $disk) | .size_human' <<<"$disks_json")
  model=$(jq -r --arg disk "$disk" '.[] | select(.name == $disk) | .model // "unknown"' <<<"$disks_json")
fi

# Confirm the erase with the exact device, size, and model.
text=$(printf 'Install %s on %s (%s, %s)?\n\nEverything on this disk will be erased.\n\nUSB disks and the live medium are not eligible.' \
  "$distro_name" "$disk" "$size" "$model")
zenity --question \
  --title="Erase disk?" \
  --text="$text" \
  --ok-label="Erase and install" \
  --cancel-label="Cancel" \
  --width=500 || exit 0

# Collect the password before the first disk write. A newline separator keeps
# passwords that contain a pipe intact.
while true; do
  form=$(zenity --forms \
    --title="Set the login password" \
    --text="Password for ${live_user}" \
    --add-password="Password" \
    --add-password="Repeat password" \
    --separator=$'\n') || exit 0
  mapfile -t fields <<<"$form"
  password=${fields[0]:-}
  repeat=${fields[1]:-}

  if [ -z "$password" ]; then
    zenity --error --title="Password required" --text="The password must not be empty." --width=400
    continue
  fi
  if [ "$password" != "$repeat" ]; then
    zenity --error --title="Passwords differ" --text="The two passwords do not match." --width=400
    continue
  fi
  break
done

printf '%s\n' "$password" > "$password_file"
unset password repeat

# Run the console installer and keep a progress dialog alive until it exits.
# The installer writes the disk, the closure, and the password. The redirect
# belongs to this user shell, so the log stays readable by the dialog.
# shellcheck disable=SC2024
sudo -n "$installer" \
  --disk "$disk" \
  --yes \
  --non-interactive \
  --password-file "$password_file" >"$log_file" 2>&1 &
installer_pid=$!

( while kill -0 "$installer_pid" 2>/dev/null; do printf '#\n'; sleep 1; done ) \
  | zenity --progress \
    --pulsate \
    --no-cancel \
    --auto-close \
    --title="Installing ${distro_name}" \
    --text="Partitioning, copying the prebuilt system, and setting the password." \
    --width=500 || true

if wait "$installer_pid"; then
  status=0
else
  status=$?
fi

if [ "$status" -ne 0 ]; then
  zenity --text-info \
    --title="Install failed" \
    --filename="$log_file" \
    --width=900 \
    --height=600
  exit 1
fi

if zenity --question \
  --title="Install complete" \
  --text="Remove the USB drive, then reboot into the installed system." \
  --ok-label="Reboot now" \
  --cancel-label="Close" \
  --width=500; then
  sudo -n systemctl reboot
fi
