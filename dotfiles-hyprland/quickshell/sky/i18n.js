.pragma library

// UI string translation for the sky shell. English text is the key and the
// fallback; `es` holds the Spanish (Spain) translations. `%1`, `%2` are
// replaced by the arguments. Used through the I18n.qml singleton.

var es = {
    // Settings window
    "Search settings": "Buscar ajustes",
    "No settings match": "Ningún ajuste coincide",
    "Displays": "Pantallas",
    "Appearance": "Apariencia",
    "Keyboard and language": "Teclado e idioma",
    "Date and time": "Fecha y hora",
    "Default apps": "Aplicaciones predeterminadas",
    "Forget network": "Olvidar red",
    "Current network": "Red actual",
    "Available networks": "Redes disponibles",
    "Advanced": "Avanzado",
    "IP address": "Dirección IP",
    "Gateway": "Puerta de enlace",
    "Link speed": "Velocidad",
    "Strong signal": "Señal fuerte",
    "Good signal": "Señal buena",
    "Weak signal": "Señal débil",
    "Secured": "Protegida",
    "Open": "Abierta",
    "Automatic": "Automático",
    "Custom": "Personalizado",
    "Custom: %1": "Personalizado: %1",
    "Applies to %1": "Se aplica a %1",
    "DNS servers": "Servidores DNS",
    "Disconnected": "Desconectada",
    "Turn it on to see networks": "Actívalo para ver las redes",
    "Password for %1": "Contraseña de %1",
    "My devices": "Mis dispositivos",
    "Nearby devices": "Dispositivos cercanos",
    "Battery %1": "Batería %1",
    "Ready to pair": "Listo para emparejar",
    "Turn it on to see devices": "Actívalo para ver los dispositivos",
    "No paired devices": "Sin dispositivos emparejados",
    "Connect a Bluetooth adapter": "Conecta un adaptador Bluetooth",
    // Launcher
    "Change wallpaper": "Cambiar fondo de pantalla",
    "Lock screen": "Bloquear pantalla",
    "Search apps, commands, or 2+2…": "Buscar aplicaciones, comandos o 2+2…",
    "↵ copy": "↵ copiar",
    "No results": "Sin resultados",

    // Media
    "Nothing playing": "No se está reproduciendo nada",
    "Unknown": "Desconocido",

    // Polkit
    "Authentication required": "Se requiere autenticación",
    "Password": "Contraseña",
    "Wrong password, try again": "Contraseña incorrecta, inténtalo de nuevo",
    "Authenticate": "Autenticar",

    // Notifications
    "Notification": "Notificación",
    "now": "ahora",

    // Control center tiles and pages
    "Silent": "Silencio",
    "%1 notifs": "%1 notificaciones",
    "None": "Ninguna",
    "Power": "Energía",
    "Session": "Sesión",
    "Notifications": "Notificaciones",
    "AI usage": "Uso de IA",
    "Sound": "Sonido",
    "Clear": "Borrar",
    "Refresh": "Actualizar",
    "Updating": "Actualizando",
    "Settings": "Ajustes",

    // Wi-Fi
    "Wi-Fi is off": "Wi-Fi desactivado",
    "Searching…": "Buscando…",
    "Wrong password": "Contraseña incorrecta",
    "Could not connect": "No se ha podido conectar",
    "Connecting…": "Conectando…",
    "Connected": "Conectado",
    "Saved": "Guardada",
    "Password": "Contraseña",
    "Connect": "Conectar",
    "Disconnect": "Desconectar",
    "Forget": "Olvidar",
    "Off": "Desactivado",
    "On": "Activado",
    "Not connected": "Sin conexión",

    // Bluetooth
    "No Bluetooth adapter": "No hay adaptador Bluetooth",
    "Bluetooth is off": "Bluetooth desactivado",
    "No adapter": "Sin adaptador",
    "Pairing…": "Emparejando…",
    "Paired": "Emparejado",
    "New": "Nuevo",
    "Pair": "Emparejar",
    "Trusted": "De confianza",
    "Trust": "Confiar",
    "Cancel": "Cancelar",

    // AI usage
    "Install codexbar to see AI usage": "Instala codexbar para ver el uso de IA",
    "Loading usage…": "Cargando uso…",
    "No providers": "Sin proveedores",
    "Operational": "Operativo",
    "%1% left": "%1% restante",
    "resetting": "reiniciando",
    "just now": "ahora mismo",
    "%1m ago": "hace %1 min",

    // Power
    "Update": "Actualizar",
    "Update (%1)": "Actualizar (%1)",
    "Lock": "Bloquear",
    "Suspend": "Suspender",
    "Log out": "Cerrar sesión",
    "Reboot": "Reiniciar",
    "Shut down": "Apagar",

    // Sound
    "Output": "Salida",
    "Apps": "Aplicaciones",
    "No apps playing audio": "Ninguna aplicación reproduce audio",
    "Microphone": "Micrófono",
    "Recording": "Grabando",

    // Tray and wallpapers
    "System tray": "Bandeja del sistema",
    "No wallpapers found": "No se han encontrado fondos de pantalla",

    // Island modules
    "Quick settings": "Ajustes rápidos",
    "Performance": "Rendimiento",
    "Music": "Música",
    "Reading sensors…": "Leyendo sensores…",
    "RAM": "RAM",
    "%1 / %2 GB used": "%1 / %2 GB usados",
    "Disks": "Discos",
    "No AMD GPU found": "No se ha encontrado una GPU AMD"
};

var tables = { es: es };

// Language code for a Config.language setting: "auto" (or empty) follows the
// LANG environment variable; unsupported languages fall back to English.
function resolve(setting, envLang) {
    var s = String(setting || "auto").toLowerCase();
    if (s === "auto") s = String(envLang || "").toLowerCase().split(/[_.@-]/)[0];
    return tables[s] ? s : "en";
}

function t(lang, text, args) {
    var table = tables[lang];
    var out = table && table[text] !== undefined ? table[text] : text;
    var list = args || [];
    return out.replace(/%(\d)/g, function (m, i) {
        var v = list[Number(i) - 1];
        return v === undefined ? m : String(v);
    });
}
