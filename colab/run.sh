#!/bin/bash

# ==========================================
#  🚀 Script de Execução de Projeto no Colab
# ==========================================

# Carrega ambiente Conda
export MAMBA_ROOT_PREFIX="micromamba"
export MPLBACKEND="Agg" # Evita erro de backend gráfico
eval "$(micromamba shell hook --shell bash)"
micromamba activate bim2idf

PROJECT_NAME=$1

if [ -z "$PROJECT_NAME" ]; then
    echo "Uso: ./run.sh <nome_do_projeto>"
    exit 1
fi

# Diretório onde o script está rodando
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DATA_DIR="$SCRIPT_DIR/projects"
PYTHON_EXEC=$(which python)

# 1. Converter para snake_case (para encontrar a pasta correta)
CLEAN_NAME="${PROJECT_NAME// /}"

# Tenta encontrar scripts/utils/string.py para conversão de nome
if [ -d "$SCRIPT_DIR/scripts" ]; then
    SCRIPTS_PARENT="$(dirname "$SCRIPT_DIR/scripts")"
elif [ -d "./scripts" ]; then
    SCRIPTS_PARENT="."
else
    # Fallback simples em bash se scripts não estiverem disponíveis
    echo "Aviso: Pasta scripts não encontrada. Tentando conversão de nome simples..."
    SNAKE_CASE_NAME=$(echo "$CLEAN_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
fi

if [ -n "$SCRIPTS_PARENT" ]; then
    SNAKE_CASE_NAME=$($PYTHON_EXEC -c "import sys; sys.path.append('$SCRIPTS_PARENT'); from scripts.utils.string import to_snake_case; print(to_snake_case('${CLEAN_NAME}'))")
fi

PROJECT_PATH="$DATA_DIR/$SNAKE_CASE_NAME"

if [ ! -d "$PROJECT_PATH" ]; then
    echo "Erro: Projeto não encontrado em $PROJECT_PATH"
    echo "Verifique se o nome está correto ou crie o projeto com ./create.sh"
    exit 1
fi

echo "=== Executando simulação para: $SNAKE_CASE_NAME ==="
echo "Diretório do projeto: $PROJECT_PATH"

# Executa o script Python separado (evitando problemas de quoting inline)
# Assume que o script run_project.py está em SCRIPTS_PARENT/scripts ou SCRIPTS_PARENT
if [ -f "$SCRIPTS_PARENT/scripts/run_project.py" ]; then
    RUN_SCRIPT="$SCRIPTS_PARENT/scripts/run_project.py"
elif [ -f "$SCRIPTS_PARENT/run_project.py" ]; then
    RUN_SCRIPT="$SCRIPTS_PARENT/run_project.py"
else
    # Fallback: Tenta achar na pasta src/scripts relativa ao script
    RUN_SCRIPT="$SCRIPT_DIR/src/scripts/run_project.py"
fi

if [ ! -f "$RUN_SCRIPT" ]; then
    echo "Erro: Script run_project.py não encontrado."
    exit 1
fi

$PYTHON_EXEC "$RUN_SCRIPT" "$PROJECT_PATH"
