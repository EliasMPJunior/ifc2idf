#!/bin/bash
# Versão adaptada do create.sh para rodar DIRETO no ambiente (sem docker exec)

# Carrega ambiente Conda
export MAMBA_ROOT_PREFIX="micromamba"
# Força backend não-interativo do Matplotlib para evitar erro no Colab
export MPLBACKEND="Agg"
eval "$(micromamba shell hook --shell bash)"
micromamba activate bim2idf

CMD_TYPE=$1
PROJECT_NAME=$2

if [ "$CMD_TYPE" == "project" ]; then
    echo "=== Gerenciamento de Projeto (Modo Colab) ==="
    
    if [ -z "$PROJECT_NAME" ]; then
        echo "Nome do projeto não fornecido."
        exit 1
    fi

    # Diretório onde o script está rodando
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    # Assume que a pasta 'scripts' está no mesmo nível do script ou em ./scripts
    if [ -d "$SCRIPT_DIR/scripts" ]; then
        SCRIPTS_DIR="$SCRIPT_DIR/scripts"
    elif [ -d "./scripts" ]; then
        SCRIPTS_DIR="./scripts"
    else
        echo "Erro: Diretório 'scripts' não encontrado em $SCRIPT_DIR/scripts nem em ./scripts"
        exit 1
    fi
    
    DATA_DIR="$SCRIPT_DIR/projects"
    PYTHON_EXEC=$(which python)

    # 1. Converter para snake_case
    CLEAN_NAME="${PROJECT_NAME// /}"
    
    # Adiciona o diretório PAI de scripts ao PYTHONPATH para importar scripts.utils.string
    # Se SCRIPTS_DIR é /path/to/scripts, precisamos adicionar /path/to ao PYTHONPATH
    PARENT_DIR="$(dirname "$SCRIPTS_DIR")"
    
    SNAKE_CASE_NAME=$($PYTHON_EXEC -c "import sys; sys.path.append('$PARENT_DIR'); from scripts.utils.string import to_snake_case; print(to_snake_case('${CLEAN_NAME}'))")
    
    if [ -z "$SNAKE_CASE_NAME" ] || [[ "$SNAKE_CASE_NAME" == *"Error"* ]] || [[ "$SNAKE_CASE_NAME" == *"exec failed"* ]]; then
        echo "Falha ao converter nome do projeto para snake_case."
        echo "Detalhes: $SNAKE_CASE_NAME"
        exit 1
    fi
    
    echo "Nome formatado: $SNAKE_CASE_NAME"

    # 2. Criar diretório
    PROJECT_DIR="$DATA_DIR/$SNAKE_CASE_NAME"
    mkdir -p "$PROJECT_DIR"
    
    # 3. Executar script Python
    echo "Inicializando estrutura..."
    
    # Executa o script create_project.py diretamente
    $PYTHON_EXEC "$SCRIPTS_DIR/create_project.py" "$PROJECT_DIR"
else
    echo "Uso: ./create.sh project <nome>"
fi
