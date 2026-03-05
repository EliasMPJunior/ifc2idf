#!/bin/bash
set -e

# Tentar localizar micromamba de forma robusta
MAMBA_EXE=""
if [ -f "/content/micromamba/bin/micromamba" ]; then
    MAMBA_EXE="/content/micromamba/bin/micromamba"
elif [ -f "/usr/local/bin/micromamba" ]; then
    MAMBA_EXE="/usr/local/bin/micromamba"
elif command -v micromamba &> /dev/null; then
    MAMBA_EXE=$(command -v micromamba)
else
    # Fallback: Tenta achar na pasta atual ou home se foi instalado localmente
    MAMBA_EXE=$(find /content -name micromamba -type f -executable | head -n 1)
fi

if [ -z "$MAMBA_EXE" ]; then
    echo "ERRO CRÍTICO: Executável 'micromamba' não encontrado."
    exit 1
fi

echo "-> Usando micromamba em: $MAMBA_EXE"
export MAMBA_ROOT_PREFIX="/content/micromamba"

# Função helper para rodar comandos dentro do ambiente conda 'bim2idf'
# Isso evita problemas com 'micromamba activate' dentro de scripts não-interativos
run_in_env() {
    $MAMBA_EXE run -n bim2idf "$@"
}

echo "=== Iniciando Setup Experimental do IFC2SB no Colab (via Conda) ==="

# 1. Instalar Dependências
# Clipper (polyclipping) é melhor instalado via APT no Ubuntu/Colab, pois o pacote conda é instável
echo "-> Instalando Clipper (libpolyclipping) via apt..."
apt-get update -qq && apt-get install -y -qq libpolyclipping-dev

# 1. Instalar Dependências de Compilação via Micromamba (Conda Forge)
# Isso traz GCC, CMake, e as bibliotecas C++ necessárias (OCCT, Boost, etc)
# REMOVIDO: ifcopenshell do conda, pois não traz headers C++. Vamos compilar do source.
echo "-> Instalando dependências de build via micromamba..."
$MAMBA_EXE install -n bim2idf -y -c conda-forge \
    compilers cmake make \
    qt \
    occt \
    boost-cpp \
    libxml2 \
    tbb-devel \
    freeimage \
    pkg-config

# Precisamos pegar o caminho do prefixo do ambiente para passar ao CMake
ENV_PREFIX=$(run_in_env printenv CONDA_PREFIX)
echo "-> Prefixo do ambiente Conda: $ENV_PREFIX"

# --- Compilar IfcOpenShell do Source ---
echo "-> Clonando e Compilando IfcOpenShell (source) para obter headers C++..."
cd /content

if [ -d "IfcOpenShell" ]; then
    echo "AVISO: Removendo diretório IfcOpenShell existente para garantir um clone limpo..."
    rm -rf IfcOpenShell
fi

# Clone SEM recursive para evitar problemas com submódulos opcionais quebrados (como svgfill)
git clone https://github.com/IfcOpenShell/IfcOpenShell.git
cd IfcOpenShell
# Usando v0.7.0 que é estável e compatível com OCCT 7.5+
git checkout v0.7.0
# Tenta atualizar submódulos essenciais, ignorando falhas em opcionais
echo "-> Atualizando submódulos (ignorando erros não críticos)..."
git submodule update --init || true

# Tentar localizar headers do OpenCascade automaticamente
echo "-> Procurando headers do OpenCascade..."
OCC_HEADER=$(find "$ENV_PREFIX" -name "Standard_Version.hxx" 2>/dev/null | head -n 1)
if [ -n "$OCC_HEADER" ]; then
    OCC_INCLUDE_DIR=$(dirname "$OCC_HEADER")
    echo "-> Headers OCCT encontrados em: $OCC_INCLUDE_DIR"
else
    echo "AVISO: Headers OCCT não encontrados. Tentando padrão..."
    OCC_INCLUDE_DIR="$ENV_PREFIX/include/opencascade"
fi

# Garantir que estamos dentro do diretório do IfcOpenShell antes de criar build
cd /content/IfcOpenShell
mkdir -p build
cd build

echo "-> Configurando IfcOpenShell..."
# Compila apenas a biblioteca estática/dinâmica C++, sem bindings Python (mais rápido)
# Instala diretamente no prefixo do ambiente Conda para que o IFC2SB encontre automaticamente
run_in_env cmake ../cmake \
    -DCMAKE_PREFIX_PATH="$ENV_PREFIX" \
    -DCMAKE_INSTALL_PREFIX="$ENV_PREFIX" \
    -DCOLLADA_SUPPORT=OFF \
    -DBUILD_IFCPYTHON=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_CONVERT=OFF \
    -DBUILD_GEOMSERVER=OFF \
    -DUSE_OCCT=ON \
    -DOCC_INCLUDE_DIR="$OCC_INCLUDE_DIR" \
    -DOCC_LIBRARY_DIR="$ENV_PREFIX/lib"

echo "-> Compilando IfcOpenShell (isso pode levar 5-10 min)..."
run_in_env make -j$(nproc)
echo "-> Instalando IfcOpenShell no ambiente..."
run_in_env make install

# --- Compilar IFC2SB ---

echo "-> Clonando repositório IFC2SB..."
cd /content
if [ ! -d "IFC2SB" ]; then
    git clone --recursive https://github.com/RWTH-E3D/IFC2SB.git
else
    cd IFC2SB
    git pull
    cd ..
fi

# 2. Compilar
echo "-> Verificando estrutura do projeto..."
cd /content/IFC2SB
ls -F

SOURCE_DIR=".."
if [ ! -f "CMakeLists.txt" ]; then
    echo "Aviso: CMakeLists.txt não encontrado na raiz."
    FOUND=$(find . -name CMakeLists.txt -not -path "*/build/*" | head -n 1)
    if [ -n "$FOUND" ]; then
        # Se achou em ./src/CMakeLists.txt, o source dir relativo ao build será ../src
        # Mas vamos simplificar: usar caminho absoluto
        SOURCE_DIR=$(dirname "$(readlink -f "$FOUND")")
        echo "-> CMakeLists.txt encontrado em: $SOURCE_DIR"
    else
        echo "ERRO CRÍTICO: CMakeLists.txt não encontrado no repositório."
        exit 1
    fi
else
    SOURCE_DIR=$(pwd)
fi

echo "-> Configurando Build com CMake..."
mkdir -p /content/IFC2SB/build
cd /content/IFC2SB/build

# Precisamos pegar o caminho do prefixo do ambiente para passar ao CMake
# Truque: rodar 'echo $CONDA_PREFIX' dentro do ambiente
# (Isso já foi feito acima)

# Apontar CMake para o prefixo do ambiente Conda onde as libs estão
# E usar o clipper do sistema (/usr/include/polyclipping)
# Nota: Não precisamos mais passar IFCOPENSHELL_INCLUDE_DIR manualmente se o 'make install' acima funcionou corretamente
# e instalou em $ENV_PREFIX/include. Mas por segurança, mantemos a lógica de busca se falhar.

echo "-> Configurando Build do IFC2SB..."
run_in_env cmake "$SOURCE_DIR" \
    -DCMAKE_PREFIX_PATH="$ENV_PREFIX" \
    -DCMAKE_INSTALL_PREFIX="$ENV_PREFIX" \
    -DSTATIC_OCC_IFCOS=OFF \
    -DCLIPPER_INCLUDE_PATH="/usr/include/polyclipping" \
    -DOCC_INCLUDE_DIR="$OCC_INCLUDE_DIR" \
    -DOCC_LIBRARY_DIR="$ENV_PREFIX/lib"

echo "-> Compilando IFC2SB (isso vai demorar)..."
run_in_env make -j$(nproc)

echo "=== Compilação Concluída ==="
echo "O executável foi gerado em: /content/IFC2SB/build/IFC2SB"

# Criar alias ou link simbólico para facilitar o uso
ln -sf /content/IFC2SB/build/IFC2SB /usr/local/bin/IFC2SB
echo "Link simbólico criado: 'IFC2SB' agora pode ser chamado no terminal."

