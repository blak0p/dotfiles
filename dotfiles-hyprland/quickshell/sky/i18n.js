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
    "%1 keys per second": "%1 teclas por segundo",
    "%1 ms": "%1 ms",
    "Accent": "Acento",
    "Applications": "Aplicaciones",
    "Archives": "Archivos comprimidos",
    "Colors follow the wallpaper": "Los colores siguen al fondo de pantalla",
    "Current layout": "Distribución actual",
    "Current time": "Hora actual",
    "Dark theme": "Tema oscuro",
    "File manager": "Gestor de archivos",
    "Follows the system language (LANG)": "Sigue el idioma del sistema (LANG)",
    "GTK theme": "Tema GTK",
    "Hardware clock": "Reloj de hardware",
    "Icon theme": "Tema de iconos",
    "Images": "Imágenes",
    "Interface language": "Idioma de la interfaz",
    "Key repeat": "Repetición de teclas",
    "Keyboard layout": "Distribución de teclado",
    "Language": "Idioma",
    "Local time": "Hora local",
    "No wallpaper": "Sin fondo de pantalla",
    "Not set": "Sin definir",
    "Not synchronized yet": "Aún sin sincronizar",
    "Only one layout configured": "Solo hay una distribución configurada",
    "Palette": "Paleta",
    "Repeat delay": "Retardo de repetición",
    "Repeat rate": "Velocidad de repetición",
    "Secondary": "Secundario",
    "Set time automatically": "Ajustar la hora automáticamente",
    "Surface": "Superficie",
    "Synchronization": "Sincronización",
    "Synchronized": "Sincronizado",
    "Tertiary": "Terciario",
    "Text": "Texto",
    "Text editor": "Editor de texto",
    "Themes": "Temas",
    "Time zone": "Zona horaria",
    "Video": "Vídeo",
    "Wallpaper": "Fondo de pantalla",
    "Web browser": "Navegador web",
    "Keyboard layouts": "Distribuciones de teclado",
    "Active": "Activa",
    "Use": "Usar",
    "Add layout": "Añadir distribución",
    "At least one layout is always kept": "Siempre se mantiene al menos una distribución",
    "Add": "Añadir",
    "Choose a layout": "Elige una distribución",
    "Variant": "Variante",
    "Default": "Predeterminada",
    "Could not save": "No se pudo guardar",
    "Applies right away": "Se aplica al instante",
    "Auto (follows the system language)": "Automático (sigue el idioma del sistema)",
    "Tonal spot": "Tonal",
    "Vibrant": "Vibrante",
    "Expressive": "Expresivo",
    "Fidelity": "Fiel",
    "Content": "Contenido",
    "Neutral": "Neutro",
    "Monochrome": "Monocromo",
    "Palette style": "Estilo de paleta",
    "Material scheme variant": "Variante del esquema Material",
    "Accent color": "Color de acento",
    "From the wallpaper": "Del fondo de pantalla",
    "Light mode is not available yet": "El modo claro aún no está disponible",
    "Applies to GTK apps": "Se aplica a las aplicaciones GTK",
    "Qt apps take theirs from qt6ct": "Las aplicaciones Qt toman el suyo de qt6ct",
    "Cursor theme": "Tema del cursor",
    "Applied now and saved for the next session": "Se aplica ahora y se guarda para la próxima sesión",
    "Cursor size": "Tamaño del cursor",
    "Position": "Posición",
    "Drag a monitor to move it, or use the arrow keys": "Arrastra un monitor para moverlo, o usa las flechas",
    "Couldn't apply this mode": "No se pudo aplicar este modo",
    "Couldn't restore the previous mode": "No se pudo restaurar el modo anterior",
    "Couldn't save the settings": "No se pudieron guardar los ajustes",
    "Layout": "Disposición",
    "No displays found": "No se han encontrado pantallas",
    "Identify": "Identificar",
    "Primary": "Principal",
    "Resolution": "Resolución",
    "Refresh rate": "Frecuencia de actualización",
    "Scale": "Escala",
    "Confirm": "Confirmar",
    "Keep these settings?": "¿Mantener esta configuración?",
    "Reverting in %1 s": "Revirtiendo en %1 s",
    "Keep": "Mantener",
    "Revert": "Revertir",
    "Apply": "Aplicar",
    "Input": "Entrada",
    "No output devices": "No hay dispositivos de salida",
    "No input devices": "No hay dispositivos de entrada",
    "No apps using audio": "Ninguna aplicación usa audio",
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
