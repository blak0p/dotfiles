#!/usr/bin/env bash
# Random wallpaper from wallhaven.cc — landscapes, cities, nature, scenery.
# Uses the public wallhaven.cc API (no key needed for SFW search).

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
PICTURES_DIR=$(get_pictures_dir)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$PICTURES_DIR/Wallpapers"
illogicalImpulseConfigPath="$HOME/.config/illogical-impulse/config.json"
userAgent=$(jq -r '.networking.userAgent // empty' "$illogicalImpulseConfigPath" 2>/dev/null)

# wallhaven.cc public API: SFW, landscapes/scenery category (category 111 = general+anime+people,
# we use 100 = general only for real-world scenery), purity 100 = SFW only.
# When WALLFLIPER_TAGS is set, override the tag pool with the active style
# preset's tags so the fetched wallpaper matches the chosen aesthetic.
# Purity bits: 100=SFW, 010=sketchy, 001=NSFW. Category: 100=general, 010=anime, 001=people.
# Tags: landscape, scenery, nature, city, etc. Pick a random page (1..100) for variety.
# We request limit=24 (the API default) and filter for landscape (w/h >= 1.2)
# so the wallpaper doesn't crop on a horizontal monitor.
page=$((1 + RANDOM % 100))
if [ -n "$WALLFLIPER_TAGS" ]; then
    IFS=" " read -ra tag_pool <<< "$WALLFLIPER_TAGS"
else
    tag_pool=("landscape" "scenery" "nature" "mountains" "forest" "sky" "minimalist")
fi
tag=${tag_pool[$RANDOM % ${#tag_pool[@]}]}

link=""
for attempt in 1 2 3 4 5; do
    api_url="https://wallhaven.cc/api/v1/search?categories=100&purity=100&sorting=relevance&q=${tag}&page=${page}"
    response=$(curl -s -A "$userAgent" "$api_url")
    # jq: parse resolution "WxH" string, filter >= 2560x1440 AND landscape (w/h >= 1.2)
    link=$(echo "$response" | jq -r '
        [.data[] | select(
            ((.resolution | split("x") | .[0] | tonumber) >= 2560) and
            ((.resolution | split("x") | .[1] | tonumber) >= 1440) and
            ((.resolution | split("x") | .[0] | tonumber) /
             (.resolution | split("x") | .[1] | tonumber) >= 1.2)
        )] | .[0].path // empty
    ')
    if [ -n "$link" ]; then
        break
    fi
    tag=${tag_pool[$RANDOM % ${#tag_pool[@]}]}
    page=$((1 + RANDOM % 100))
done

if [ -z "$link" ]; then
    exit 1
fi

ext=$(echo "$link" | awk -F. '{print $NF}')
downloadPath="$PICTURES_DIR/Wallpapers/random_wallhaven.${ext}"
currentWallpaperPath=$(jq -r '.background.wallpaperPath' "$illogicalImpulseConfigPath")
if [ "$downloadPath" == "$currentWallpaperPath" ]; then
    downloadPath="$PICTURES_DIR/Wallpapers/random_wallhaven-1.${ext}"
fi

curl -s -A "$userAgent" "$link" -o "$downloadPath"
"$SCRIPT_DIR/../switchwall.sh" --image "$downloadPath"