FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

ENV HOST=0.0.0.0
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y \
        git \
        build-essential \
        portaudio19-dev \
        python3.11 \
        python3.11-dev \
        python3-pip \
        ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Create symbolic link for python
RUN ln -sf /usr/bin/python3.11 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

# Set up OpenCL for NVIDIA
RUN mkdir -p /etc/OpenCL/vendors \
    && echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd

# Clone AllTalk repository
RUN git clone -b alltalkbeta https://github.com/erew123/alltalk_tts .

# Install PyTorch and other Python dependencies
RUN pip install --no-cache-dir torch==2.2.1 torchvision==0.17.1 torchaudio==2.2.1 --index-url https://download.pytorch.org/whl/cu121 \
    && pip install --no-cache-dir faiss-cpu \
    && pip install --no-cache-dir -r system/requirements/requirements_standalone.txt \
    && pip install --no-cache-dir gradio==4.32.2 \
    && pip install --no-cache-dir deepspeed \
    && pip install --no-cache-dir -r system/requirements/requirements_parler.txt \
    && pip install --no-cache-dir transformers==4.40.2

EXPOSE 7851

# Create launch script
RUN echo '#!/bin/sh\n\
uvicorn tts_server:app --host 0.0.0.0 --port 7851 --workers 1 --proxy-headers & \n\
sleep 5\n\
exec python script.py\n' > /app/launch.sh \
    && chmod +x /app/launch.sh

ENTRYPOINT ["/app/launch.sh"]