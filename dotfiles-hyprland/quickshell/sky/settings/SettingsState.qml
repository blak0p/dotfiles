pragma Singleton
import QtQuick
import Quickshell

// Open/closed state and current page of the sky settings window (Super+I).
Singleton {
    id: root

    property bool shown: false
    property string page: "wifi"

    // Sidebar entries. `keys` are extra search words (English and Spanish),
    // `file` is the page component loaded on demand.
    readonly property var pages: [
        { id: "wifi", icon: "wifi", label: "Wi-Fi", file: "WifiPage.qml",
          keys: "wifi wireless network internet password vpn ip dns red redes contraseña" },
        { id: "bluetooth", icon: "bluetooth", label: "Bluetooth", file: "BluetoothPage.qml",
          keys: "bluetooth devices pair headphones mouse keyboard dispositivos emparejar auriculares" },
        { id: "displays", icon: "desktop_windows", label: "Displays", file: "DisplaysPage.qml",
          keys: "displays monitors screens resolution refresh rate scale pantallas monitores resolución escala frecuencia" },
        { id: "sound", icon: "volume_up", label: "Sound", file: "AudioPage.qml",
          keys: "sound audio volume output input microphone speakers sonido volumen salida entrada micrófono altavoces" },
        { id: "appearance", icon: "palette", label: "Appearance", file: "AppearancePage.qml",
          keys: "appearance wallpaper colors theme apariencia fondo colores tema" },
        { id: "keyboard", icon: "keyboard", label: "Keyboard and language", file: "KeyboardPage.qml",
          keys: "keyboard layout language input teclado distribución idioma" },
        { id: "time", icon: "schedule", label: "Date and time", file: "TimePage.qml",
          keys: "date time timezone clock ntp fecha hora zona horaria reloj" },
        { id: "apps", icon: "apps", label: "Default apps", file: "DefaultAppsPage.qml",
          keys: "default apps applications browser file manager mime aplicaciones predeterminadas navegador" }
    ]

    function pageInfo(id) { return pages.find(p => p.id === id) || pages[0]; }

    function open(p) {
        if (p && pages.some(x => x.id === p)) page = p;
        shown = true;
    }
    function close() { shown = false; }
    function toggle(p) {
        if (shown && (!p || p === page)) close();
        else open(p);
    }
}
