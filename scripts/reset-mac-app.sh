#!/bin/bash
# Removes Unwatched and its local data from this Mac, so the next install starts with onboarding.
# iCloud data (backups, synced library, synced settings) is left alone.
# The terminal needs Full Disk Access, macOS blocks the app's data folders otherwise.
#
# Usage: scripts/reset-mac-app.sh [--dry-run]

set -euo pipefail

id=com.pentlandFirth.Unwatched
group=group.$id
lib=$HOME/Library

candidates=(
    "/Applications/Unwatched.app"
    "$lib/Containers/$id"
    "$lib/Group Containers/$group"
    "$lib/Application Scripts/$id"
    "$lib/Application Scripts/$id.UnwatchedWidget"
    "$lib/Application Scripts/$group"
    "$lib/Application Scripts/com.pentandFirth.Unwatched" # misspelled id of early builds
    "$lib/Caches/$id"
    "$lib/HTTPStorages/$id"
    "$lib/HTTPStorages/$id.binarycookies"
    "$lib/WebKit/$id"
)

# Xcode builds can sit anywhere, but each one registers its extensions
while IFS= read -r app; do
    candidates+=("$app")
done < <(pluginkit -mAvv 2>/dev/null |
    sed -n 's|^[[:space:]]*Path = \(.*/Unwatched\.app\)/Contents/PlugIns/.*|\1|p' | sort -u)

targets=()
for path in "${candidates[@]}"; do
    if [[ -e $path ]]; then targets+=("$path"); fi
done

if [[ ${#targets[@]} -eq 0 ]]; then
    echo "Nothing to remove."
    exit 0
fi

echo "Will remove:"
printf '  %s\n' "${targets[@]}"

if [[ ${1:-} == --dry-run ]]; then exit 0; fi

if pgrep -f '/Contents/MacOS/Unwatched( |$)' >/dev/null; then
    echo "Unwatched is running. Quit it first." >&2
    exit 1
fi

read -r -p "Delete these? [y/N] " answer
if [[ $answer != [yY] ]]; then
    echo "Cancelled."
    exit 0
fi

failed=0
for path in "${targets[@]}"; do
    rm -rf "$path" || true
    if [[ -e $path ]]; then
        echo "Couldn't remove: $path" >&2
        failed=1
    fi
done

# cfprefsd would otherwise write its cached settings back
killall cfprefsd 2>/dev/null || true

if [[ $failed -eq 1 ]]; then
    echo "Give your terminal Full Disk Access in System Settings, restart it, then run this again." >&2
    exit 1
fi
echo "Done. Install Unwatched again to start with onboarding."
