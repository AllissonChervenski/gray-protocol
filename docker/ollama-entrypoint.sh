#!/usr/bin/env bash
# Entrypoint do container do Oráculo (Ollama).
# Sobe o servidor, garante que o modelo está baixado e mantém o servidor no ar.
set -e

# 1. Inicia o servidor Ollama em background
ollama serve &
SERVER_PID=$!

# 2. Espera o servidor responder antes de tentar baixar o modelo
echo "[oraculo] Aguardando o servidor Ollama subir..."
until ollama list >/dev/null 2>&1; do
  sleep 1
done

# 3. Baixa o modelo (idempotente: se já está no volume, é praticamente instantâneo)
echo "[oraculo] Garantindo o modelo ${OLLAMA_MODEL}..."
ollama pull "${OLLAMA_MODEL}"

echo "[oraculo] Pronto. Modelo ${OLLAMA_MODEL} disponível em :11434."

# 4. Mantém o servidor em primeiro plano (PID 1 do container)
wait "${SERVER_PID}"
