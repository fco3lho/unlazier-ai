#!/bin/bash
set -e

CONFIG_DIR="${HOME}/.config/opencode"
BACKUP_DIR="${CONFIG_DIR}.bak.$(date +%Y%m%d%H%M%S)"

if [ ! -d "$CONFIG_DIR" ]; then
    echo "Nothing to uninstall. $CONFIG_DIR does not exist."
    exit 0
fi

echo "Backing up current config to $BACKUP_DIR"
cp -r "$CONFIG_DIR" "$BACKUP_DIR"

echo "Removing $CONFIG_DIR..."
rm -rf "$CONFIG_DIR"

echo "Uninstalled. Backup saved at $BACKUP_DIR"
