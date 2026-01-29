#!/bin/bash

# ==========================================
#  🎨 Script de Inicialização e Gerenciamento
# ==========================================

# Definição de Cores e Estilos
BOLD="\033[1m"
GREEN="\033[0;32m"
RED="\033[0;31m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
MAGENTA="\033[0;35m"
RESET="\033[0m"

# Funções de Logging
log_header() { echo -e "\n${BOLD}${MAGENTA}=== $1 ===${RESET}"; }
log_info()   { echo -e "  ${BLUE}ℹ${RESET}  $1"; }
log_success(){ echo -e "  ${GREEN}✔${RESET}  $1"; }
log_error()  { echo -e "  ${RED}✖${RESET}  $1"; }
log_warn()   { echo -e "  ${YELLOW}⚠${RESET}  $1"; }

# Variáveis de Configuração
COMPOSE_FILE="docker/compose/docker-compose.yml"
CONTAINER_NAME="bim2idf"

# ==========================================
#  1. Verificação e Inicialização do Container
# ==========================================

log_header "Verificando Ambiente Docker"

# Verifica se o container está rodando
if [ "$(docker ps -q -f name=${CONTAINER_NAME})" ]; then
    log_success "Container '${CONTAINER_NAME}' já está rodando."
else
    log_warn "Container '${CONTAINER_NAME}' não encontrado ou parado."
    log_info "Iniciando container (force-recreate, build)..."
    
    docker compose -f "${COMPOSE_FILE}" up --force-recreate --build -d
    
    if [ $? -eq 0 ]; then
        log_success "Container iniciado com sucesso!"
    else
        log_error "Falha ao iniciar o container."
        exit 1
    fi
fi

# ==========================================
#  2. Gerenciamento de Projetos
# ==========================================

CMD_TYPE=$1
PROJECT_NAME=$2

if [ "$CMD_TYPE" == "project" ]; then
    log_header "Gerenciamento de Projeto"

    if [ -z "$PROJECT_NAME" ]; then
        log_error "Nome do projeto não fornecido."
        echo -e "  Uso: $0 project <nome_do_projeto>"
        exit 1
    fi

    log_info "Processando projeto: ${BOLD}${PROJECT_NAME}${RESET}"

    # 1. Converter para snake_case usando o script Python dentro do container
    # O container mapeia ../../src:/app, então o módulo está em /app/scripts/utils/string.py
    # Precisamos garantir que o python encontre o módulo. Adicionamos /app ao PYTHONPATH.
    
    PYTHON_EXEC="/opt/conda/bin/python"
    
    # Remove espaços do nome do projeto antes de converter para garantir um snake_case limpo
    CLEAN_NAME="${PROJECT_NAME// /}"
    
    SNAKE_CASE_NAME=$(docker exec "${CONTAINER_NAME}" "${PYTHON_EXEC}" -c "import sys; sys.path.append('/app'); from scripts.utils.string import to_snake_case; print(to_snake_case('${CLEAN_NAME}'))")
    
    if [ -z "$SNAKE_CASE_NAME" ] || [[ "$SNAKE_CASE_NAME" == *"Error"* ]] || [[ "$SNAKE_CASE_NAME" == *"exec failed"* ]]; then
        log_error "Falha ao converter nome do projeto para snake_case."
        log_error "Detalhes: $SNAKE_CASE_NAME"
        exit 1
    fi

    log_info "Nome formatado (snake_case): ${CYAN}${SNAKE_CASE_NAME}${RESET}"

    # 2. Verificar se diretório já existe e criar
    PROJECT_DIR="/data/wip/${SNAKE_CASE_NAME}"
    
    # Check existence
    EXISTS=$(docker exec "${CONTAINER_NAME}" bash -c "if [ -d '${PROJECT_DIR}' ]; then echo 'yes'; else echo 'no'; fi")
    
    if [ "$EXISTS" == "yes" ]; then
        log_error "O diretório do projeto já existe: ${PROJECT_DIR}"
        exit 1
    fi

    log_info "Criando diretório: ${PROJECT_DIR}"
    docker exec "${CONTAINER_NAME}" mkdir -p "${PROJECT_DIR}"

    if [ $? -ne 0 ]; then
        log_error "Falha ao criar diretório."
        exit 1
    fi

    # 3. Executar script de criação de projeto
    log_info "Inicializando estrutura do projeto..."
    
    # Debug: Mostrar configurações do GIT PYTHON
    log_info "Configurações GitPython:"
    docker exec "${CONTAINER_NAME}" env | grep GIT_PYTHON
    
    # O script python refatorado espera o caminho do projeto
    docker exec -w /app "${CONTAINER_NAME}" "${PYTHON_EXEC}" scripts/create_project.py "${PROJECT_DIR}"

    if [ $? -eq 0 ]; then
        log_success "Projeto '${SNAKE_CASE_NAME}' criado com sucesso!"
    else
        log_error "Erro ao executar script de criação do projeto."
        exit 1
    fi

else
    log_info "Nenhum comando de projeto detectado. Ambiente pronto."
    echo -e "  Dica: Para criar um projeto, use: $0 project <nome>"
fi

echo -e "\n"
