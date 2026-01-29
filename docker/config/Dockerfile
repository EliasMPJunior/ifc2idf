ARG PYTHON_VERSION=3.10

FROM mambaorg/micromamba:2.0.2

# Redeclare the ARG after FROM, but don't set a default value
ARG PYTHON_VERSION

# Set the Python version as an environment variable
ENV PYTHON_VERSION=${PYTHON_VERSION}

# Copy the environment file
COPY --chown=$MAMBA_USER:$MAMBA_USER docker/config/env.yaml /tmp/env.yaml

RUN echo "Python version argument: ${PYTHON_VERSION}"

# Modify the env.yaml file to include the specified Python version
RUN micromamba install -y -n base -c conda-forge python=${PYTHON_VERSION} pythonocc-core=7.7.0 ifcopenshell lark pip gcc gxx git --retry-clean-cache && \
    micromamba clean --all --yes

# Copy files
COPY --chown=$MAMBA_USER:$MAMBA_USER . .

ARG MAMBA_DOCKERFILE_ACTIVATE=1

ENV PIP_DEFAULT_TIMEOUT=500
ENV GIT_PYTHON_REFRESH=quiet
ENV GIT_PYTHON_GIT_EXECUTABLE=/usr/bin/git

# Install ebcpy and teaser via pip since they're not available on conda-forge
RUN pip install --no-cache-dir ebcpy teaser fmpy

# Install the package
# RUN pip install --no-cache-dir '.' -i https://pypi.tuna.tsinghua.edu.cn/simple

# Ensure the correct geomeppy fork is installed for Python 3.10+ compatibility
RUN pip install --force-reinstall --no-cache-dir git+https://github.com/BIM2SIM/geomeppy@fix_dependencies

# Install numpy-stl
RUN pip install --no-cache-dir numpy-stl gitpython rwthcolors

RUN pip install --upgrade "pint>=0.24.1" "pint-pandas>=0.6"
# Minimal EnergyPlus install (9.4.0)
USER root
ENV ENERGYPLUS_VERSION=9.4.0
ENV ENERGYPLUS_TAG=v9.4.0
ENV ENERGYPLUS_SHA=998c4b761e
ENV ENERGYPLUS_INSTALL_VERSION=9-4-0
ENV ENERGYPLUS_DOWNLOAD_BASE_URL=https://github.com/NREL/EnergyPlus/releases/download/$ENERGYPLUS_TAG
ENV ENERGYPLUS_DOWNLOAD_FILENAME=EnergyPlus-$ENERGYPLUS_VERSION-$ENERGYPLUS_SHA-Linux-Ubuntu18.04-x86_64.sh
ENV ENERGYPLUS_DOWNLOAD_URL=$ENERGYPLUS_DOWNLOAD_BASE_URL/$ENERGYPLUS_DOWNLOAD_FILENAME

# System libs + download installer
RUN apt-get update && apt-get install -y ca-certificates curl libx11-6 libexpat1 && rm -rf /var/lib/apt/lists/*
RUN curl -SLO --retry 5 --retry-delay 15 --retry-max-time 900 --connect-timeout 60 --max-time 3600 $ENERGYPLUS_DOWNLOAD_URL || (sleep 30 && curl -SLO --retry 5 --retry-delay 15 --retry-max-time 900 --connect-timeout 60 --max-time 3600 $ENERGYPLUS_DOWNLOAD_URL)
RUN chmod +x $ENERGYPLUS_DOWNLOAD_FILENAME
RUN echo "y\r" | ./$ENERGYPLUS_DOWNLOAD_FILENAME
RUN rm $ENERGYPLUS_DOWNLOAD_FILENAME

# Strip non-essential content to keep image small
RUN cd /usr/local/EnergyPlus-$ENERGYPLUS_INSTALL_VERSION \
    && rm -rf DataSets Documentation ExampleFiles WeatherData MacroDataSets PostProcess/convertESOMTRpgm \
       PostProcess/EP-Compare PreProcess/FMUParser PreProcess/ParametricPreProcessor PreProcess/IDFVersionUpdater

# Remove broken symlinks, keep /usr/local/bin tools accessible
RUN cd /usr/local/bin && find -L . -type l -delete

# Back to mamba user
USER $MAMBA_USER

WORKDIR /app
