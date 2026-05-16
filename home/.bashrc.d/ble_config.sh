[ -n "$AXIOM_BUNKER" ] && return
# ==========================================================
# CONFIGURACIÓN MAESTRA DE BLE.SH (CORREGIDA)
# ==========================================================

if [[ ${BLE_VERSION-} ]]; then

  # --- 1. RESALTADO DE SINTAXIS (Nombres actualizados para Nightly) ---
  ble-face -s syntax_varname          fg=orange
  ble-face -s syntax_quoted           fg=green
  ble-face -s syntax_comment          fg=242,italic
  ble-face -s syntax_option           fg=purple
  ble-face -s syntax_keyword          fg=blue,bold
  ble-face -s syntax_function_name    fg=cyan,bold
  ble-face -s command_builtin         fg=blue,bold
  ble-face -s command_alias           fg=cyan

  # --- 2. INTERFAZ Y COLORES ---
  ble-face -s auto_complete           fg=239,italic
  ble-face -s region                  bg=60,fg=white
  ble-face -s menu_filter_fixed       fg=black,bg=yellow
  ble-face -s menu_filter_input       fg=black,bg=117

  # --- 3. ATAJOS DE TECLADO ---
  ble-bind -f 'C-j' 'forward-char'
  ble-bind -f 'TAB' 'menu-complete'
  ble-bind -f 'C-BS' 'backward-kill-word'

  # --- 4. COMPORTAMIENTO ---
  set ble_opt_input_bracketed_paste=
  set ble_opt_auto_complete_delay=0
  set ble_opt_menu_complete_timeout=0

  # --- 5. INTEGRACIÓN CON FZF ---
  ble-import contrib/fzf

fi
