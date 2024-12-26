FROM continuumio/miniconda3:24.7.1-0

# Arguments
ARG TTS_MODEL="xtts"
ARG ALLTALK_DIR=/opt/alltalk
ARG CUDA_VERSION
ARG PYTHON_VERSION

# Environment variables
ENV TTS_MODEL=$TTS_MODEL
ENV SHELL=/bin/bash
ENV HOST=0.0.0.0
ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_DOCKER_ARCH=all
ENV NVIDIA_VISIBLE_DEVICES=all
ENV CONDA_AUTO_UPDATE_CONDA="false"
ENV GRADIO_SERVER_NAME="0.0.0.0"

##############################################################################
# Installation/Basic Utilities
##############################################################################
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install --no-install-recommends -y \
      espeak-ng \
      curl \
      wget \
      jq \
      vim && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR ${ALLTALK_DIR}

##############################################################################
# Create conda environment
##############################################################################
COPY docker/conda/build/environment-${CUDA_VERSION}-py${PYTHON_VERSION}.yml environment.yml
RUN conda env create -f environment.yml && \
    conda clean -a -y

# Make RUN commands use the new environment
SHELL ["conda", "run", "-n", "alltalk", "/bin/bash", "-c"]

##############################################################################
# Install python dependencies
##############################################################################
COPY system/config system/config
COPY system/requirements/requirements_standalone.txt system/requirements/requirements_standalone.txt
COPY system/requirements/requirements_parler.txt system/requirements/requirements_parler.txt

RUN pip install --no-cache-dir -r system/requirements/requirements_standalone.txt && \
    pip install --no-cache-dir --upgrade gradio==4.32.2 && \
    pip install --no-cache-dir -r system/requirements/requirements_parler.txt && \
    conda clean --all --force-pkgs-dirs -y && \
    pip cache purge

##############################################################################
# Install DeepSpeed
##############################################################################
RUN mkdir -p /tmp/deepspeed
COPY docker/deepspeed/build/*.whl /tmp/deepspeed/
RUN DEEPSPEED_WHEEL=$(realpath /tmp/deepspeed/*.whl) && \
    CFLAGS="-I$CONDA_PREFIX/include/" LDFLAGS="-L$CONDA_PREFIX/lib/" \
    pip install --no-cache-dir ${DEEPSPEED_WHEEL} && \
    rm -rf /tmp/deepspeed && \
    conda clean --all --force-pkgs-dirs -y && \
    pip cache purge

# Copy the rest of the application
COPY . .

##############################################################################
# Setup firstrun and create directories
##############################################################################
RUN echo $'#!/usr/bin/env bash \n\
conda run -n alltalk python ./system/config/firstrun.py $@' > ./start_firstrun.sh && \
    chmod +x start_firstrun.sh && \
    ./start_firstrun.sh --tts_model $TTS_MODEL && \
    mkdir -p ${ALLTALK_DIR}/outputs && \
    mkdir -p /root/.triton/autotune

##############################################################################
# Enable deepspeed and setup RVC
##############################################################################
RUN find . -name model_settings.json -exec sed -i -e 's/"deepspeed_enabled": false/"deepspeed_enabled": true/g' {} \; && \
    jq -r '.[]' system/tts_engines/rvc_files.json > /tmp/rvc_files.txt && \
    xargs -n 1 curl --create-dirs --output-dir models/rvc_base -LO < /tmp/rvc_files.txt && \
    rm -f /tmp/rvc_files.txt

# Create start scripts
COPY docker/scripts/start_*.sh ./
RUN chmod +x start_*.sh

ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "alltalk", "./start_alltalk.sh"]