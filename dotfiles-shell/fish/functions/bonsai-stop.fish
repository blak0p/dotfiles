function bonsai-stop
    pkill -f llama-server
    distrobox enter dev-container -- pkill -f "hermes gateway"
    echo "Bonsai (host) y el gateway de Hermes (bunker) parados"
end
