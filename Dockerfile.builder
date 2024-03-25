# This file is based on https://github.com/dusty-nv/jetson-containers packages/pytorch/Dockerfile.builder
# NVIDIA instructions for compiling from source at https://forums.developer.nvidia.com/t/pytorch-for-jetson/72048
#
# Dockerfile for building PyTorch from source
# see the other Dockerfile & config.py for package configuration/metadata
#
ARG BASE_IMAGE=python:3.11
FROM --platform=arm64 ${BASE_IMAGE} AS tools

# Docker build arguments passed from `config.py`
ARG PYTORCH_BUILD_VERSION=2.2.0
ARG PYTORCH_BUILD_NUMBER=1
ARG PYTORCH_BUILD_EXTRA_ENV=None

# From jetson-containers/jetson_containers/l4t_version.py
# Nano/TX1 = 5.3, TX2 = 6.2, Xavier = 7.2, Orin = 8.7
ARG TORCH_CUDA_ARCH_ARGS=8.7

# https://github.com/pytorch/pytorch?tab=readme-ov-file#from-source
# install prerequisites
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libopenblas-dev \
        libopenmpi-dev \
        openmpi-bin \
        openmpi-common \
        gfortran \
        libomp-dev \
        git \
        ca-certificates \
        python3-pip \
        python3-dev \
        cmake \
        build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# https://developer.nvidia.com/cuda-downloads?target_os=Linux&target_arch=arm64-sbsa&Compilation=Native&Distribution=Ubuntu&target_version=22.04&target_type=deb_network
RUN <<NUR
    set -ex
    curl -LO https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/sbsa/cuda-keyring_1.1-1_all.deb
    dpkg -i cuda-keyring_1.1-1_all.deb
    apt-get update
    apt-get -y install cuda-toolkit-12-3
NUR

# Adding sm_87 (only needed for PyTorch 2.0)
#ARG CPP_EXTENSION_PY_FILE=/opt/pytorch/torch/utils/cpp_extension.py
#RUN sed -z "s|       ('Turing', '7.5+PTX'),\n        ('Ampere', '8.0;8.6+PTX'),|       ('Turing', '7.5+PTX'),\n        ('Ampere+Tegra', '8.7'),('Ampere', '8.0;8.6+PTX'),|" -i ${CPP_EXTENSION_PY_FILE} && \
#    sed "s|'8.6', '8.9'|'8.6', '8.7', '8.9'|" -i ${CPP_EXTENSION_PY_FILE} && \
#    sed -n 1729,1746p ${CPP_EXTENSION_PY_FILE}

# Build PyTorch wheel with extra environmental variables for custom feature switch
RUN git clone --branch v${PYTORCH_BUILD_VERSION} --depth=1 --recursive https://github.com/pytorch/pytorch /tmp/pytorch
WORKDIR /tmp/pytorch
ENV USE_NCCL=0
ENV USE_QNNPACK=0
ENV USE_PYTORCH_QNNPACK=0
ENV USE_NATIVE_ARCH=1
# Comment out or set to 1 for OpenMPI support
ENV USE_DISTRIBUTED=0
ENV USE_TENSORRT=0
ENV TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_ARGS}
ENV CUDAARCHS=87
RUN <<NUR
    set -ex
    python3 -m venv .venv
    . .venv/bin/activate
    pip3 install -r requirements.txt
    pip3 install --no-cache-dir scikit-build ninja
NUR

FROM --platform=arm64 tools
RUN <<NUR
    python3 setup.py bdist_wheel
NUR
RUN cp dist/*.whl /opt
WORKDIR /
# RUN rm -rf /tmp/pytorch

# install the compiled wheel
RUN pip3 install --verbose /opt/torch*.whl

RUN python3 -c 'import torch; print(f"PyTorch version: {torch.__version__}"); print(f"CUDA available:  {torch.cuda.is_available()}"); print(f"cuDNN version:   {torch.backends.cudnn.version()}"); print(f"torch.distributed:   {torch.distributed.is_available()}"); print(torch.__config__.show());'

# patch for https://github.com/pytorch/pytorch/issues/45323
RUN PYTHON_ROOT=`pip3 show torch | grep Location: | cut -d' ' -f2` && \
    TORCH_CMAKE_CONFIG=$PYTHON_ROOT/torch/share/cmake/Torch/TorchConfig.cmake && \
    echo "patching _GLIBCXX_USE_CXX11_ABI in ${TORCH_CMAKE_CONFIG}" && \
    sed -i 's/  set(TORCH_CXX_FLAGS "-D_GLIBCXX_USE_CXX11_ABI=")/  set(TORCH_CXX_FLAGS "-D_GLIBCXX_USE_CXX11_ABI=0")/g' ${TORCH_CMAKE_CONFIG}

# set the torch hub model cache directory to mounted /data volume
ENV TORCH_HOME=/data/models/torch

WORKDIR /
