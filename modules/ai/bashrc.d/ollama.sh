export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_KEEP_ALIVE=0

ollama-update() {
  ~/scripts/update-ollama-models.sh
}
