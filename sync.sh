#!/bin/bash
set -euo pipefail

# Load config
if [[ ! -f config.json ]]; then
    echo "Error: config.json not found. Copy config.example.json to config.json and configure it."
    exit 1
fi

DEST=$(python3 -c "import json; print(json.load(open('config.json'))['dest'])")
SOURCE="desk/"

if [[ -z "$DEST" ]]; then
    echo "Error: 'dest' not set in config.json"
    exit 1
fi

# Initial sync
echo "Starting sync: $SOURCE -> $DEST"
rsync -av --delete "$SOURCE" "$DEST"

# Watch for changes and sync
fswatch -o "$SOURCE" | while read f; do
    echo "Change detected, syncing..."
    rsync -av --delete "$SOURCE" "$DEST"
    echo "Sync complete at $(date +%H:%M:%S)"
done
