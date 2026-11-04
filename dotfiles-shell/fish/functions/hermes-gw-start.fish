function hermes-gw-start
    distrobox enter dev-container -- fish -c "hermes gateway > ~/hermes-gateway.log 2>&1 &disown" &
    disown
    echo "Gateway de Hermes arrancando en background dentro del bunker 'dev-container'"
end
