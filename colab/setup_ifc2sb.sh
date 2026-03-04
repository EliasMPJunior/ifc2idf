#!/bin/bash
set -e

# Carregar ambiente micromamba (assumindo que setup.sh já rodou)
export MAMBA_ROOT_PREFIX="/content/micromamba"
eval "$($MAMBA_ROOT_PREFIX/bin/micromamba shell hook -s posix)"
micromamba activate bim2idf

echo "=== Iniciando Setup Experimental do IFC2SB no Colab (via Conda) ==="

# 1. Instalar Dependências de Compilação via Micromamba (Conda Forge)
# Isso traz GCC, CMake, e as bibliotecas C++ necessárias (OCCT, IfcOpenShell, Boost)
echo "-> Instalando dependências de build via micromamba..."
micromamba install -y -c conda-forge \
    compilers cmake make \
    occt=7.5.0 \
    ifcopenshell=0.6.0 \
    boost-cpp \
    libxml2 \
    clipper \
    tbb-devel \
    freeimage \
    pkg-config

# Nota: O pacote 'ifcopenshell' no conda forge geralmente inclui headers C++ em $CONDA_PREFIX/include
# O mesmo para 'occt'.

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
echo "-> Configurando Build com CMake..."
mkdir -p /content/IFC2SB/build
cd /content/IFC2SB/build

# Apontar CMake para o prefixo do ambiente Conda onde as libs estão
cmake .. \
    -DCMAKE_PREFIX_PATH=$MAMBA_ROOT_PREFIX/envs/bim2idf \
    -DCMAKE_INSTALL_PREFIX=$MAMBA_ROOT_PREFIX/envs/bim2idf \
    -DSTATIC_OCC_IFCOS=OFF \
    -DCLIPPER_INCLUDE_PATH=$MAMBA_ROOT_PREFIX/envs/bim2idf/include/polyclipping

echo "-> Compilando (isso vai demorar)..."
make -j$(nproc)

echo "=== Compilação Concluída ==="
echo "O executável foi gerado em: /content/IFC2SB/build/IFC2SB"

# Criar alias ou link simbólico para facilitar o uso
ln -sf /content/IFC2SB/build/IFC2SB /usr/local/bin/IFC2SB
echo "Link simbólico criado: 'IFC2SB' agora pode ser chamado no terminal."

