#!/usr/bin/env bash
# Sobe o Oráculo (Ollama + modelo, via Docker) e lança o jogo (Godot nativo).
# Uso: ./run.sh
set -euo pipefail
cd "$(dirname "$0")"

CONTAINER="oraculo-ollama"

# --- 1. Verifica dependências ------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "ERRO: Docker não encontrado no PATH. Instale o Docker e tente de novo." >&2
  exit 1
fi

# Resolve o binário do Godot. Ordem de busca:
#   1) $GODOT_BIN (se definido)         2) 'godot' no PATH
#   3) locais comuns por SO (auto-detecção)
resolve_godot() {
  # 1) Variável de ambiente explícita
  if [ -n "${GODOT_BIN:-}" ]; then
    if [ -x "$GODOT_BIN" ] || command -v "$GODOT_BIN" >/dev/null 2>&1; then
      echo "$GODOT_BIN"; return 0
    fi
    echo "AVISO: GODOT_BIN='$GODOT_BIN' não é executável; tentando outras opções..." >&2
  fi
  # 2) 'godot' no PATH
  if command -v godot >/dev/null 2>&1; then
    command -v godot; return 0
  fi
  # 3) Locais comuns (glob ordenado por versão, mais novo primeiro)
  local candidatos=(
    "$HOME"/Godot/Godot_v4.*-stable_linux.x86_64
    "$HOME"/Godot/Godot_v4.*_linux.x86_64
    "$HOME"/Downloads/Godot_v4.*_linux.x86_64
    /Applications/Godot.app/Contents/MacOS/Godot
    "$HOME"/Applications/Godot.app/Contents/MacOS/Godot
    /usr/local/bin/godot /usr/bin/godot
  )
  local c
  for c in $(printf '%s\n' "${candidatos[@]}" | sort -rV); do
    if [ -x "$c" ]; then echo "$c"; return 0; fi
  done
  return 1
}

if ! GODOT="$(resolve_godot)"; then
  echo "ERRO: não encontrei o Godot." >&2
  echo "Faça uma destas opções:" >&2
  echo "  • aponte o binário:  GODOT_BIN=/caminho/para/godot ./run.sh" >&2
  echo "  • ou coloque 'godot' no PATH (Godot 4.6)." >&2
  exit 1
fi
echo ">> Usando Godot: $GODOT"

# Suporta tanto 'docker compose' (v2) quanto 'docker-compose' (v1)
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
else
  DC="docker-compose"
fi

# --- 2. Sobe o modelo --------------------------------------------------------
echo ">> Subindo o Oráculo (Ollama + modelo)..."
$DC up -d

# Garante que o container será parado ao fechar o jogo
cleanup() {
  echo ">> Encerrando o Oráculo..."
  $DC down
}
trap cleanup EXIT

# --- 3. Espera o modelo ficar pronto ----------------------------------------
echo ">> Aguardando o modelo ficar pronto (na primeira vez baixa ~2 GB, pode demorar)..."
until [ "$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null)" = "healthy" ]; do
  sleep 2
done
echo ">> Modelo pronto."

# --- 4. Lança o jogo ---------------------------------------------------------
echo ">> Iniciando o jogo..."
"$GODOT" --path .
