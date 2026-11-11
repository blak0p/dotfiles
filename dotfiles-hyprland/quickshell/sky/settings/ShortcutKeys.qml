import QtQuick
import qs

// A key combination drawn as keycaps: ["SUPER", "SHIFT", "S"] -> [Super][Shift][S].
Row {
    id: r

    property var keys: []
    property bool dim: false

    spacing: 5

    function label(k) {
        const map = { SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift", Return: "Enter", space: "Space",
                      Page_Up: "PgUp", Page_Down: "PgDn", BackSpace: "Backspace", Escape: "Esc" };
        if (map[k]) return map[k];
        if (k.startsWith("XF86")) return k.slice(4);
        if (k.startsWith("mouse:")) return I18n.t("Mouse %1", k.slice(6));
        if (k.startsWith("code:")) return I18n.t("Key %1", k.slice(5));
        return k.length === 1 ? k.toUpperCase() : k.charAt(0).toUpperCase() + k.slice(1);
    }

    Repeater {
        model: r.keys
        Rectangle {
            required property string modelData
            height: 28
            width: Math.max(28, cap.implicitWidth + 18)
            radius: 8
            color: Theme.surface
            border.width: 1
            border.color: Qt.alpha(Theme.outline, 0.6)
            opacity: r.dim ? 0.55 : 1
            Text {
                id: cap
                anchors.centerIn: parent
                text: r.label(parent.modelData)
                color: Theme.fg
                font.family: "Google Sans Flex"; font.pixelSize: 12; font.weight: Font.DemiBold
            }
        }
    }
}
