#!/bin/bash

# Check if the OS is Ubuntu
if ! grep -qi "ubuntu" /etc/os-release; then
  echo "This script is intended to run only on Ubuntu systems."
  exit 1
fi

# Check if snap is installed
if ! command -v snap >/dev/null 2>&1; then
  echo "Snap is not installed on this system."
  exit 1
fi

# Get the list of installed snaps (excluding the header)
snaps=$(snap list | awk 'NR>1 {print $1}')

# Check if any snaps are installed
if [ -z "$snaps" ]; then
  echo "No snap packages installed."
  exit 0
fi

# Iterate through the list and remove each snap
for snap in $snaps; do
  echo "Removing snap package: $snap"
  sudo snap remove --purge "$snap"
done

echo "All removable snap packages have been removed."
