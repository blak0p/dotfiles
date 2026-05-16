[ -n "$AXIOM_BUNKER" ] && return
# Cambia el 'eval' normal por este que es compatible con ble.sh
if [[ ${BLE_VERSION-} ]]; then
  eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/mi_tema.omp.json --no-exit-code)"
else
  eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/mi_tema.omp.json)"
fi
