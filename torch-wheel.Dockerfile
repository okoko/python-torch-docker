ARG PYTORCH_BUILD_VERSION=2.7.0
# https://catalog.ngc.nvidia.com/orgs/nvidia/containers/l4t-cuda/tags
ARG BASE_IMAGE=nvcr.io/nvidia/l4t-cuda:12.2.12-devel

# Builder stage for x86 wheel, just a dummy for now
FROM scratch AS amd64


# Builder stage for arm64 wheel
FROM ${BASE_IMAGE} AS arm64

ENV DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,id=bookworm-/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=bookworm-/var/lib/apt \
    <<NUR
    set -ex
    rm -f /etc/apt/apt.conf.d/docker-clean
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
    apt-get update
    apt-get install -y software-properties-common
    add-apt-repository ppa:deadsnakes/ppa
    apt-get install -y --no-install-recommends \
            libopenblas-dev \
            libopenmpi-dev \
            openmpi-bin \
            openmpi-common \
            gfortran \
            libomp-dev \
            git \
            python3.11 \
            python3.11-dev \
            python3.11-distutils \
            build-essential \
            cmake
NUR

RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python3.11 get-pip.py

# Switch from py 3.10 (default on base image) to 3.11. This is needed for pytorch that works with 3.11
RUN <<NUR
    set -ex
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
    update-alternatives --set python3 /usr/bin/python3.11
    update-alternatives --install /usr/bin/pip pip /usr/local/bin/pip3.11 1
    update-alternatives --set pip /usr/local/bin/pip3.11
NUR
RUN pip3 uninstall -y numpy && pip3 install numpy

ARG PYTORCH_BUILD_VERSION
RUN git clone --branch v${PYTORCH_BUILD_VERSION} --depth=1 --recursive https://github.com/pytorch/pytorch /tmp/pytorch

# Build PyTorch wheel for Jetson
# TORCH_CUDA_ARCH_LIST: Xavier = 7.2, Orin = 8.7
ARG PYTORCH_BUILD_NUMBER=1
RUN --mount=type=cache,target=/opt/ccache \
    <<NUR
    set -ex
    cd /tmp/pytorch
    export USE_NCCL=0
    export USE_QNNPACK=0
    export USE_PYTORCH_QNNPACK=0
    export USE_NATIVE_ARCH=1
    export USE_DISTRIBUTED=1
    export USE_TENSORRT=0
    export TORCH_CUDA_ARCH_LIST="7.2;8.7"
    export PYTHON_VERSION=3.11
    pip3 install -r requirements.txt
    pip3 install --no-cache-dir scikit-build ninja
    python3 setup.py bdist_wheel
    cp dist/*.whl /
    rm -rf /tmp/pytorch
NUR

# Alias to copy files from in next stage
FROM ${TARGETARCH} AS wheels

# We only want to store the wheel in the final image
FROM scratch AS wheel-container

COPY --from=wheels /*.whl /

LABEL org.opencontainers.image.authors="Marko Kohtala <marko.kohtala@okoko.fi>"
LABEL org.opencontainers.image.url="https://hub.docker.com/r/okoko/python-torch"
LABEL org.opencontainers.image.documentation="https://github.com/okoko/python-torch-docker"
LABEL org.opencontainers.image.source="https://github.com/okoko/python-torch-docker"
LABEL org.opencontainers.image.vendor="Software Consulting Kohtala Ltd"
LABEL org.opencontainers.image.licenses="(BSD-3 AND Python-2.0)"
LABEL org.opencontainers.image.title="PyTorch wheels"
