# syntax=docker/dockerfile:1

ARG PYTHON=3.14.2
ARG TORCH=2.10.0
ARG TORCH_REQUIREMENT="torch==${TORCH}"
ARG EXTRA_INDEX_URL="https://download.pytorch.org/whl/cu126/"
ARG TORCH_WHEEL_SOURCE="scratch"
ARG TORCHVISION_WHEEL_SOURCE="scratch"
ARG CREATED
ARG SOURCE_COMMIT
ARG CONSTRAINTS=constraints-2.10.0.txt

# Using variable in RUN --mount=from gives error 'from' doesn't support variable expansion, define alias stage instead
FROM ${TORCH_WHEEL_SOURCE} AS torch-wheel-image
FROM ${TORCHVISION_WHEEL_SOURCE} AS torchvision-wheel-image


FROM python:${PYTHON}

ARG TARGETPLATFORM
RUN --mount=type=cache,target=/var/cache/apt,id=trixie-/var/cache/apt-${TARGETPLATFORM} \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=trixie-/var/lib/apt-${TARGETPLATFORM} \
    --mount=from=torch-wheel-image,src=/,target=/tmp/torch-wheels \
    <<NUR
    set -ex
# To keep cache of downloaded .debs, replace docker configuration
    rm -f /etc/apt/apt.conf.d/docker-clean
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
    apt-get update
    export DEBIAN_FRONTEND=noninteractive
    apt-get upgrade -y --no-install-recommends
    if ls /tmp/torch-wheels/*.whl 1> /dev/null 2>&1
    then
        apt-get install -y --no-install-recommends \
            cuda-cudart-12-6 \
            cuda-cupti-12-6 \
            libcublas-12-6 \
            libcudnn9-cuda-12 \
            libcufft-12-6 \
            libcufile-12-6 \
            libcurand-12-6 \
            libcusparse-12-6 \
            libnvjitlink-12-6
    fi
NUR

COPY README.md LICENSE /

ARG CONSTRAINTS
ARG TORCH_REQUIREMENT
ARG EXTRA_INDEX_URL
RUN --mount=src=${CONSTRAINTS},target=/tmp/constraints.txt \
    --mount=from=torch-wheel-image,src=/,target=/tmp/torch-wheels \
    --mount=from=torchvision-wheel-image,src=/,target=/tmp/torchvision-wheels \
    <<NUR
    set -ex
    # If any torch wheel files exist, install from those, otherwise install from PyPi
    if ls /tmp/torch-wheels/*.whl 1> /dev/null 2>&1
    then
        TORCH_INSTALL="/tmp/torch-wheels/*.whl"
    else
        TORCH_INSTALL=${TORCH_REQUIREMENT}
    fi
    # If any torchvision wheel files exist, install them
    if ls /tmp/torchvision-wheels/*.whl 1> /dev/null 2>&1
    then
        TORCHVISION_INSTALL="/tmp/torchvision-wheels/*.whl"
    else
        TORCHVISION_INSTALL=""
    fi

    pip install --no-cache-dir \
        -c /tmp/constraints.txt \
        ${EXTRA_INDEX_URL:+--extra-index-url ${EXTRA_INDEX_URL}} \
        ${TORCH_INSTALL} ${TORCHVISION_INSTALL}
NUR

# nvidia-docker plugin uses these environment variables to provide services
# into the container. See https://github.com/NVIDIA/nvidia-docker/wiki/Usage
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/user-guide.html#driver-capabilities
ENV NVIDIA_VISIBLE_DEVICES="all"
ENV NVIDIA_DRIVER_CAPABILITIES="compute,utility"
# libnvidia-ml.so location on k8s that does not run ldconfig
ENV LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64

ARG TORCH
ENV TORCH_VERSION="${TORCH}"
# Nvidia GPU device plugin on kubernetes mounts the driver here
ENV PATH=${PATH}:/usr/local/nvidia/bin

# Save memory by enabling lazy loading on CUDA 11.7+
ENV CUDA_MODULE_LOADING=LAZY

ARG PYTHON
ARG CREATED
ARG SOURCE_COMMIT
# See https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL org.opencontainers.image.authors="Marko Kohtala <marko.kohtala@okoko.fi>"
LABEL org.opencontainers.image.url="https://hub.docker.com/r/okoko/python-torch"
LABEL org.opencontainers.image.documentation="https://github.com/okoko/python-torch-docker"
LABEL org.opencontainers.image.source="https://github.com/okoko/python-torch-docker"
LABEL org.opencontainers.image.vendor="Software Consulting Kohtala Ltd"
LABEL org.opencontainers.image.licenses="(BSD-3 AND Python-2.0)"
LABEL org.opencontainers.image.title="Python with preinstalled Torch"
LABEL org.opencontainers.image.description="Python with preinstalled Torch"
LABEL org.opencontainers.image.created="${CREATED}"
LABEL org.opencontainers.image.version="${TORCH}-${PYTHON}"
LABEL org.opencontainers.image.revision="${SOURCE_COMMIT}"
LABEL org.opencontainers.image.version.python="${PYTHON}"
LABEL org.opencontainers.image.version.torch="${TORCH}"
ARG TORCH_WHEEL_SOURCE
LABEL org.opencontainers.image.torch-wheel-source="${TORCH_WHEEL_SOURCE}"
