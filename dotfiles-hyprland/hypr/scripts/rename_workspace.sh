#!/usr/bin/env bash

export PATH="/usr/bin:/usr/local/bin:$PATH"

if pidof quickshell >/dev/null 2>&1; then
    qs -c ii ipc call workspace renameToggle 2>/dev/null && exit 0
fi

WS_ID=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' 2>/dev/null || echo "1")
STATE_FILE_1="$HOME/.local/state/quickshell/states.json"
STATE_FILE_2="$HOME/.local/state/quickshell/ii/states.json"

CURRENT_LABEL=""
if [ -f "$STATE_FILE_1" ]; then
    CURRENT_LABEL=$(python3 -c "
import json
try:
    with open('$STATE_FILE_1') as f:
        d = json.load(f)
    lbls = d.get('workspaceLabels', [])
    idx = int('$WS_ID') - 1
    if isinstance(lbls, list) and 0 <= idx < len(lbls):
        print(lbls[idx])
    elif isinstance(lbls, dict):
        print(lbls.get('$WS_ID', ''))
except Exception:
    pass
" 2>/dev/null || echo "")
fi

ROFI_THEME='
window { width: 420px; location: center; anchor: center; border-radius: 20px; background-color: #141318; border: 1px; border-color: #48464c; padding: 18px; }
mainbox { background-color: transparent; children: [ inputbar ]; }
inputbar { background-color: #211f26; border-radius: 12px; padding: 10px 14px; children: [ prompt, entry ]; spacing: 10px; }
prompt { text-color: #d0bcff; font: "sans-serif bold 11"; background-color: transparent; }
entry { text-color: #e6e1e5; placeholder-color: #938f96; font: "sans-serif 11"; background-color: transparent; }
listview { lines: 0; }
'

ROFI_CMD=(rofi -dmenu -p "Workspace $WS_ID" -theme-str "$ROFI_THEME")

if [ -n "$CURRENT_LABEL" ]; then
    ROFI_CMD+=(-filter "$CURRENT_LABEL")
fi

# Pass empty stdin so Rofi returns empty string when user clears the text entry
NEW_LABEL=$(printf "" | "${ROFI_CMD[@]}" 2>/dev/null)
ROFI_EXIT=$?

if [ $ROFI_EXIT -ne 0 ]; then
    exit 0
fi

python3 - "$WS_ID" "$NEW_LABEL" "$STATE_FILE_1" "$STATE_FILE_2" << 'EOF'
import sys, json, os

ws_id = int(sys.argv[1])
new_label = sys.argv[2].strip()
files = sys.argv[3:]

for file_path in files:
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    try:
        with open(file_path, 'r') as f:
            data = json.load(f)
    except Exception:
        data = {}

    lbls = data.get('workspaceLabels', [])
    if not isinstance(lbls, list):
        lbls = [""] * 10

    while len(lbls) < 10:
        lbls.append("")

    idx = ws_id - 1
    if 0 <= idx < 10:
        lbls[idx] = new_label

    data['workspaceLabels'] = lbls

    with open(file_path, 'w') as f:
        json.dump(data, f, indent=4)
EOF
