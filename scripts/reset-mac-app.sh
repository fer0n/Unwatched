#!/bin/bash
# Removes Unwatched and its local data from this Mac, so the next install starts with onboarding.
# iCloud data (backups, synced library, synced settings) is left alone.
# The terminal needs Full Disk Access, macOS blocks the app's data folders otherwise.
#
# Usage: scripts/reset-mac-app.sh [--dry-run]

set -euo pipefail

dry_run=false
case "${1:-}" in
    "") ;;
    --dry-run) dry_run=true ;;
    *)
        echo "Usage: $0 [--dry-run]" >&2
        exit 2
        ;;
esac

id=com.pentlandFirth.Unwatched
group=group.$id
lib=$HOME/Library

candidates=(
    "/Applications/Unwatched.app"
    "$lib/Group Containers/$group"
    "$lib/Application Scripts/$group"
    "$lib/Application Scripts/com.pentandFirth.Unwatched" # misspelled id of early builds
    "$lib/Application Support/$id"
    "$lib/Caches/$id"
    "$lib/HTTPStorages/$id"
    "$lib/HTTPStorages/$id.binarycookies"
    "$lib/WebKit/$id"
)

for suffix in "" .UnwatchedWidget .UnwatchedSafariExtension .ShareExtension; do
    candidates+=("$lib/Containers/$id$suffix" "$lib/Application Scripts/$id$suffix")
done

# Xcode builds can sit anywhere, but each one registers its extensions
plugins=$(pluginkit -mAvv)
while IFS= read -r app; do
    if [[ -n $app ]]; then candidates+=("$app"); fi
done < <(sed -n 's|^[[:space:]]*Path = \(.*/Unwatched\.app\)/Contents/PlugIns/.*|\1|p' <<<"$plugins" | sort -u)

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

if [[ $dry_run == true ]]; then exit 0; fi

if pgrep -f '/Contents/MacOS/Unwatched( |$)' >/dev/null; then
    echo "Unwatched is running. Quit it first." >&2
    exit 1
fi

read -r -p "Delete these? [y/N] " answer
if [[ $answer != [yY] ]]; then
    echo "Cancelled."
    exit 0
fi

# a running extension could recreate the shared container
pkill -f '/Unwatched\.app/Contents/PlugIns/' || true

app_failed=false
data_failed=false
for path in "${targets[@]}"; do
    rm -rf "$path" || true
    if [[ -e $path ]]; then
        echo "Couldn't remove: $path" >&2
        if [[ $path == *.app ]]; then app_failed=true; else data_failed=true; fi
    fi
done

# cfprefsd would otherwise write its cached settings back
killall cfprefsd 2>/dev/null || true

if [[ $app_failed == true ]]; then
    echo "Move Unwatched to the Trash in Finder, then run this again." >&2
fi
if [[ $data_failed == true ]]; then
    echo "Give your terminal Full Disk Access in System Settings, restart it, then run this again." >&2
fi
if [[ $app_failed == true || $data_failed == true ]]; then exit 1; fi

echo "Done. Install Unwatched again to start with onboarding."
