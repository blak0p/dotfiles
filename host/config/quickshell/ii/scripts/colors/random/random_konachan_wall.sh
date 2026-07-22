#!/usr/bin/env bash

get_pictures_dir() {
    if command -v xdg-user-dir &> /dev/null; then
        xdg-user-dir PICTURES
        return
    fi

    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
    if [ -f "$config_file" ]; then
        local pictures_path
        pictures_path=$(source "$config_file" >/dev/null 2>&1; echo "$XDG_PICTURES_DIR")
        echo "${pictures_path/#\$HOME/$HOME}"
        return
    fi

    echo "$HOME/Pictures"
}

QUICKSHELL_CONFIG_NAME="ii"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
PICTURES_DIR=$(get_pictures_dir)
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$PICTURES_DIR/Wallpapers"
illogicalImpulseConfigPath="$HOME/.config/illogical-impulse/config.json"
userAgent=$(jq -r '.networking.userAgent // empty' "$illogicalImpulseConfigPath" 2>/dev/null)

# Konachan-only random wallpaper (SFW).
# When WALLFLIPER_TAGS is set (space-separated), override the tag pool.
# Tags use `+` as the booru AND separator (not %20).
if [ -n "$WALLFLIPER_TAGS" ]; then
    IFS=" " read -ra tag_pool_raw <<< "$WALLFLIPER_TAGS"
    tag_pool=()
    for t in "${tag_pool_raw[@]}"; do
        tag_pool+=("${t// /+}")
    done
else
    tag_pool=(
        "idol"
        "portrait"
        "cute"
        "beautiful"
        "dress"
        "long_hair"
        "anime_girl"
        "smile"
        "hat"
        "uniform"
        "glasses"
        "twintails"
        "blonde"
        "brown_hair"
        "blue_eyes"
        "casual"
        "skirt"
        "ribbon"
        "hair_ornament"
        "sailor_uniform"
    )
fi
# Fallback User-Agent.
[ -z "$userAgent" ] && userAgent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
link=""
for attempt in 1 2 3 4 5; do
    tag=${tag_pool[$RANDOM % ${#tag_pool[@]}]}
    page=$((1 + RANDOM % 200))
    # konachan.net: rating:s (safe) — no nudity, no explicit content
    api_url="https://konachan.net/post.json?tags=rating%3As+${tag}&limit=10&page=${page}"
    response=$(curl -s -A "$userAgent" "$api_url")
    link=$(echo "$response" | jq -r '
        [.[] | select(
            ((.width / .height) >= 1.2) and
            ((.width >= 2560 and .height >= 1440) or (.width >= 1920 and .height >= 1080)) and
            ((.tags | test("loli|shota|child|toddler|baby|kindergarten|grade_school|nude|nsfw|sex|porn|ero|hentai|yaoi|yuri"; "i")) | not)
        )] | .[0].file_url // empty
    ' 2>/dev/null)
    if [ -n "$link" ]; then
        break
    fi
done

if [ -z "$link" ]; then
    exit 1
fi
ext=$(echo "$link" | awk -F. '{print $NF}')
downloadPath="$PICTURES_DIR/Wallpapers/random_wallpaper.$ext"
currentWallpaperPath=$(jq -r '.background.wallpaperPath' "$illogicalImpulseConfigPath")
if [ "$downloadPath" == "$currentWallpaperPath" ]; then
    downloadPath="$PICTURES_DIR/Wallpapers/random_wallpaper-1.$ext"
fi
curl -A "$userAgent" "$link" -o "$downloadPath"
"$SCRIPT_DIR/../switchwall.sh" --image "$downloadPath"
