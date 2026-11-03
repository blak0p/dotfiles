import Quickshell
import Quickshell.Wayland
import qs

// Empty, click-through window whose only job is to reserve screen space.
PanelWindow {
    id: w
    required property string edge
    required property real zone

    anchors {
        top: edge !== "bottom"
        bottom: edge !== "top"
        left: edge !== "right"
        right: edge !== "left"
    }
    // Top/bottom span the width, left/right span the height.
    implicitWidth: (edge === "left" || edge === "right") ? 1 : 0
    implicitHeight: (edge === "top" || edge === "bottom") ? 1 : 0
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: zone
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "sky-reserve"
    color: "transparent"
    mask: Region {}
}
