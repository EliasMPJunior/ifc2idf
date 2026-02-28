#!/bin/bash
set -euo pipefail

# ==========================================
#  🎨 Script de Setup para Google Colab
# ==========================================

# 1. Configurar Micromamba (substituto leve para Conda)
if [ ! -f /usr/local/bin/micromamba ]; then
    echo "📦 Instalando Micromamba..."
    curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba
    mv bin/micromamba /usr/local/bin/micromamba
    chmod +x /usr/local/bin/micromamba
fi

# 2. Criar ambiente virtual similar ao Docker
echo "🐍 Criando ambiente Conda 'bim2idf'..."
export MAMBA_ROOT_PREFIX="/content/micromamba"
micromamba create -y -n bim2idf -c conda-forge \
    python=3.10 pythonocc-core=7.7.0 ifcopenshell lark pip gcc gxx git

# 3. Inicializar shell para usar o ambiente
eval "$(micromamba shell hook --shell bash)"
micromamba activate bim2idf

# 4. Instalar dependências PIP (mesmas do Dockerfile)
echo "📦 Instalando dependências PIP..."
pip install --no-cache-dir ebcpy teaser fmpy
pip install --force-reinstall --no-cache-dir git+https://github.com/BIM2SIM/geomeppy@fix_dependencies
pip install --no-cache-dir numpy-stl gitpython rwthcolors scienceplots
pip install --upgrade "pint>=0.24.1" "pint-pandas>=0.6"

# 5. Instalar bim2sim (com --no-deps para evitar conflito de ifcopenshell)
echo "📦 Instalando bim2sim..."
pip install "git+https://github.com/BIM2SIM/bim2sim.git@v0.3.0" --no-deps
# Instalar dependências restantes manualmente se necessário, mas o ambiente já deve ter quase tudo
pip install pydantic==2.11.7 # Dependência específica que estava sendo baixada

# 6. Instalar EnergyPlus
echo "⚡ Instalando EnergyPlus 9.4.0..."
ENERGYPLUS_VERSION=9.4.0
ENERGYPLUS_TAG=v9.4.0
ENERGYPLUS_SHA=998c4b761e
ENERGYPLUS_INSTALL_VERSION=9-4-0
ENERGYPLUS_DOWNLOAD_BASE_URL="https://github.com/NREL/EnergyPlus/releases/download/${ENERGYPLUS_TAG}"
ENERGYPLUS_DOWNLOAD_FILENAME="EnergyPlus-${ENERGYPLUS_VERSION}-${ENERGYPLUS_SHA}-Linux-Ubuntu18.04-x86_64.sh"
ENERGYPLUS_DOWNLOAD_URL="${ENERGYPLUS_DOWNLOAD_BASE_URL}/${ENERGYPLUS_DOWNLOAD_FILENAME}"

# Dependências de sistema para EnergyPlus
apt-get update && apt-get install -y ca-certificates curl libx11-6 libexpat1

curl -SLO "${ENERGYPLUS_DOWNLOAD_URL}"
chmod +x "${ENERGYPLUS_DOWNLOAD_FILENAME}"
echo "y\r" | "./${ENERGYPLUS_DOWNLOAD_FILENAME}"
rm "${ENERGYPLUS_DOWNLOAD_FILENAME}"

# Limpeza do EnergyPlus (igual ao Dockerfile)
cd "/usr/local/EnergyPlus-${ENERGYPLUS_INSTALL_VERSION}" && \
  rm -rf DataSets Documentation ExampleFiles WeatherData MacroDataSets PostProcess/convertESOMTRpgm \
         PostProcess/EP-Compare PreProcess/FMUParser PreProcess/ParametricPreProcessor PreProcess/IDFVersionUpdater

# Links simbólicos
cd /usr/local/bin && find -L . -type l -delete

# 7. Configurar variáveis de ambiente
echo "🔧 Configurando variáveis de ambiente..."
export GIT_PYTHON_REFRESH=quiet
export GIT_PYTHON_GIT_EXECUTABLE=/usr/bin/git
export PYTHONPATH="/content/src:$PYTHONPATH"

# 8. Dar permissão de execução ao script create.sh existente
echo "🔨 Configurando permissões do create.sh..."
if [ -f "create.sh" ]; then
    chmod +x create.sh
    echo "✅ Permissão de execução concedida ao create.sh"
else
    echo "⚠️ Aviso: create.sh não encontrado no diretório atual."
fi

echo "✅ Setup concluído! Para criar um projeto, use:"
echo "   ./create.sh project 'Meu Projeto'"
