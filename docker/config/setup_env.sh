#!/usr/bin/env bash
set -euo pipefail

PYTHON_VERSION="${PYTHON_VERSION:-3.10}"

pip install --no-cache-dir pythonocc-core || echo "Aviso: pythonocc-core não pôde ser instalado via pip neste ambiente. Continuando sem esse pacote." >&2
pip install --no-cache-dir ifcopenshell lark ebcpy teaser fmpy

pip install --no-cache-dir ebcpy teaser fmpy
pip install --force-reinstall --no-cache-dir git+https://github.com/BIM2SIM/geomeppy@fix_dependencies
pip install --no-cache-dir numpy-stl gitpython rwthcolors scienceplots
pip install --upgrade "pint>=0.24.1" "pint-pandas>=0.6"

ENERGYPLUS_VERSION=9.4.0
ENERGYPLUS_TAG=v9.4.0
ENERGYPLUS_SHA=998c4b761e
ENERGYPLUS_INSTALL_VERSION=9-4-0
ENERGYPLUS_DOWNLOAD_BASE_URL="https://github.com/NREL/EnergyPlus/releases/download/${ENERGYPLUS_TAG}"
ENERGYPLUS_DOWNLOAD_FILENAME="EnergyPlus-${ENERGYPLUS_VERSION}-${ENERGYPLUS_SHA}-Linux-Ubuntu18.04-x86_64.sh"
ENERGYPLUS_DOWNLOAD_URL="${ENERGYPLUS_DOWNLOAD_BASE_URL}/${ENERGYPLUS_DOWNLOAD_FILENAME}"

apt-get update && apt-get install -y ca-certificates curl libx11-6 libexpat1 && rm -rf /var/lib/apt/lists/*

curl -SLO --retry 5 --retry-delay 15 --retry-max-time 900 --connect-timeout 60 --max-time 3600 "${ENERGYPLUS_DOWNLOAD_URL}" || \
  (sleep 30 && curl -SLO --retry 5 --retry-delay 15 --retry-max-time 900 --connect-timeout 60 --max-time 3600 "${ENERGYPLUS_DOWNLOAD_URL}")

chmod +x "${ENERGYPLUS_DOWNLOAD_FILENAME}"
echo "y\r" | "./${ENERGYPLUS_DOWNLOAD_FILENAME}"
rm "${ENERGYPLUS_DOWNLOAD_FILENAME}"

cd "/usr/local/EnergyPlus-${ENERGYPLUS_INSTALL_VERSION}" && \
  rm -rf DataSets Documentation ExampleFiles WeatherData MacroDataSets PostProcess/convertESOMTRpgm \
         PostProcess/EP-Compare PreProcess/FMUParser PreProcess/ParametricPreProcessor PreProcess/IDFVersionUpdater

cd /usr/local/bin && find -L . -type l -delete
