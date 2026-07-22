#!/usr/bin/env bash
# Random anime wallpaper from waifu.im (SFW — "cachondas" style).
# Tags: waifu, oppai, uniform, selfies — anime girls, sexy but safe.
# Falls back to "waifu" when WALLFLIPER_TAGS is not set.

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

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
PICTURES_DIR=$(get_pictures_dir)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
illogicalImpulseConfigPath="$HOME/.config/illogical-impulse/config.json"

mkdir -p "$PICTURES_DIR/Wallpapers"

userAgent=$(jq -r '.networking.userAgent // empty' "$illogicalImpulseConfigPath" 2>/dev/null)
userAgent="${userAgent:-Mozilla/5.0}"

if [ -n "$WALLFLIPER_TAGS" ]; then
    IFS=" " read -ra tag_pool <<< "$WALLFLIPER_TAGS"
else
    tag_pool=("waifu" "oppai" "uniform" "maid")
fi

link=""
for attempt in 1 2 3 4 5; do
    tag=${tag_pool[$RANDOM % ${#tag_pool[@]}]}
    api_url="https://api.waifu.im/images?IsNsfw=False&Orientation=Landscape&PageSize=30&IncludedTags=${tag}"
    response=$(curl -s -A "$userAgent" "$api_url")
    link=$(echo "$response" | jq -r '
        ([.items[] | select(
            (.width / .height) >= 1.2 and
            .width >= 1920
        )] | .[0].url) // (.items[0].url // empty)
    ' 2>/dev/null)
    if [ -n "$link" ]; then
        break
    fi
done

if [ -z "$link" ]; then
    exit 1
fi

ext=$(echo "$link" | awk -F. '{print $NF}')
ext="${ext:-jpg}"
downloadPath="$PICTURES_DIR/Wallpapers/random_waifu.${ext}"
currentWallpaperPath=$(jq -r '.background.wallpaperPath' "$illogicalImpulseConfigPath" 2>/dev/null)
if [ "$downloadPath" == "$currentWallpaperPath" ]; then
    downloadPath="$PICTURES_DIR/Wallpapers/random_waifu-1.${ext}"
fi

curl -s -A "$userAgent" "$link" -o "$downloadPath"
"$SCRIPT_DIR/../switchwall.sh" --image "$downloadPath"
