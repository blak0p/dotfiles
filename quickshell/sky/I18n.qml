pragma Singleton
import Quickshell
import "i18n.js" as L

// UI language for the shell: Config.language, or the system LANG on "auto".
// I18n.t("Text") returns the translation; I18n.t("%1 notifs", n) fills %1.
Singleton {
    readonly property string lang: L.resolve(Config.language, Quickshell.env("LANG"))

    function t(text, a, b) {
        return L.t(lang, text, [a, b]);
    }
}
