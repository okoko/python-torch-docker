ARG PYTORCH_BUILD_VERSION=2.10.0
# https://docs.nvidia.com/deploy/cuda-compatibility/minor-version-compatibility.html
ARG CUDA_VERSION=12.6
ARG PYTHON_VERSION=3.14

# On trixie /usr/include/x86_64-linux-gnu/bits/mathcalls.h has incompatible declarations with CUDA headers

FROM ubuntu:24.04 AS base

# https sources require ca-certificates first
ARG TARGETARCH
RUN --mount=type=cache,target=/var/cache/apt,id=trixie-/var/cache/apt-${TARGETARCH} \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=trixie-/var/lib/apt-${TARGETARCH} \
    <<NUR
    # To keep cache of downloaded .debs, replace docker configuration
    rm -f /etc/apt/apt.conf.d/docker-clean
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
    apt-get update
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends ca-certificates
NUR


FROM --platform=linux/amd64 base AS tooling-amd64
# https://developer.nvidia.com/cuda-12-6-0-download-archive?target_os=Linux&target_arch=x86_64&Distribution=Debian&target_version=12&target_type=deb_network
# I take Ubuntu 24.04 that is based on trixie as Debian 13 trixie is not yet listed
ADD https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb /
RUN <<NUR
    dpkg -i cuda-keyring_1.1-1_all.deb
NUR

# https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#compute-capability
# https://developer.nvidia.com/cuda/gpus
# Default x86 TORCH_CUDA_ARCH_LIST='5.0;6.0;7.0;7.5;8.0;8.6;9.0;'
# We have GTX 2080 7.5 and A16 8.6
# CUDA 12.6 supported up to compute capability 9.0
# CUDA 12.8 dropped support for compute capabilities 5.0;6.0;7.0, added 10.0
ENV TORCH_CUDA_ARCH_LIST='7.5;8.0;8.6;9.0;'


FROM --platform=linux/arm64 base AS tooling-arm64
# JP 6.2.1 L4T 36.4.7
# https://repo.download.nvidia.com/jetson/#Jetpack%206.1/6.2/6.2.1
# https://docs.nvidia.com/jetson/jetpack/install-setup/index.html
ADD --chmod=644 https://repo.download.nvidia.com/jetson/jetson-ota-public.asc /etc/apt/keyrings/jetson-ota-public.asc
ADD https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/arm64/cuda-keyring_1.1-1_all.deb /
RUN <<NUR
    echo "576f852981855e5c6cfb9b625ffb51b984ca451f1181b2e70435b005034fad55  /etc/apt/keyrings/jetson-ota-public.asc" | sha256sum -c -
    cat <<-EOF > /etc/apt/sources.list.d/nvidia-l4t-apt-source.list
	deb [signed-by=/etc/apt/keyrings/jetson-ota-public.asc] https://repo.download.nvidia.com/jetson/common r36.4 main
	deb [signed-by=/etc/apt/keyrings/jetson-ota-public.asc] https://repo.download.nvidia.com/jetson/t234 r36.4 main
	EOF

    dpkg -i cuda-keyring_1.1-1_all.deb
NUR

# TORCH_CUDA_ARCH_LIST: Xavier = 7.2, Orin = 8.7
ENV TORCH_CUDA_ARCH_LIST='7.2;8.7'


FROM tooling-${TARGETARCH} AS tooling

COPY deadsnakes-ubuntu-ppa-noble.sources /etc/apt/sources.list.d/

ARG CUDA_VERSION
ARG PYTHON_VERSION
RUN --mount=type=cache,target=/var/cache/apt,id=trixie-/var/cache/apt-${TARGETARCH} \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=trixie-/var/lib/apt-${TARGETARCH} \
    <<NUR
    # To keep cache of downloaded .debs, replace docker configuration
    rm -f /etc/apt/apt.conf.d/docker-clean
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
    apt-get update
    CUDA=${CUDA_VERSION%.*}-${CUDA_VERSION#*.}
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        gcc-13 g++-13 \
        git \
        python${PYTHON_VERSION}-dev \
        cuda-compiler-${CUDA} \
        cuda-libraries-dev-${CUDA} \
        cuda-command-line-tools-${CUDA} \
        cuda-nvml-dev-${CUDA} \
        libcudnn9-dev-cuda-${CUDA_VERSION%.*} \
        libomp-dev \
        python3-numpy-dev python3-numpy
NUR
# libopenmpi-dev ?

RUN <<NUR
    update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++-13 100
    update-alternatives --install /usr/bin/cc cc /usr/bin/gcc-13 100
    ln -sf gcc-13 /usr/bin/gcc
    ln -sf g++-13 /usr/bin/g++
    ln -sf cpp-13 /usr/bin/cpp
NUR
ENV PATH=/usr/local/cuda-${CUDA_VERSION}/bin:/usr/local/cuda-${CUDA_VERSION}/nvvm/bin:/usr/lib/llvm-19/bin:${PATH}

ENV CUDA_VERSION=${CUDA_VERSION}
ENV PYTHON_VERSION=${PYTHON_VERSION}

ARG PYTORCH_BUILD_VERSION
RUN git clone --filter=blob:none --sparse --depth=1 --branch v${PYTORCH_BUILD_VERSION} https://github.com/pytorch/pytorch /pytorch
ADD https://bootstrap.pypa.io/get-pip.py /
RUN python${PYTHON_VERSION} /get-pip.py

RUN pip install --root-user-action=ignore --break-system-packages -r /pytorch/requirements.txt

ENV USE_NCCL=0
# ENV USE_QNNPACK=0
ENV USE_PYTORCH_QNNPACK=0
ENV USE_NATIVE_ARCH=1
ENV USE_DISTRIBUTED=0
ENV USE_TENSORRT=0
# Trixie comes with gcc 14 while Ubuntu 24.04 has gcc 13
# ENV TORCH_NVCC_FLAGS="-allow-unsupported-compiler"


FROM --platform=${BUILDPLATFORM} python:${PYTHON_VERSION} AS source
# This is a separate stage to allow building with --build-context source= of already cloned repo
# And in case running both builds on same host, avoids re-downloading for both architectures

ARG PYTORCH_BUILD_VERSION
RUN git clone --depth=1 --recursive --branch v${PYTORCH_BUILD_VERSION} https://github.com/pytorch/pytorch /pytorch


FROM tooling AS build
# Build PyTorch wheel
ARG PYTORCH_BUILD_NUMBER=1
RUN --mount=from=source,src=/pytorch,target=/pytorch \
    <<NUR
    cd /pytorch
    python${PYTHON_VERSION} setup.py bdist_wheel
    find -name '*.whl' -ls
NUR


# We only want to store the wheel in the final image
FROM scratch AS wheel-container

COPY --from=wheels /pytorch/dist/*.whl /

LABEL org.opencontainers.image.authors="Marko Kohtala <marko.kohtala@okoko.fi>"
LABEL org.opencontainers.image.url="https://hub.docker.com/r/okoko/python-torch"
LABEL org.opencontainers.image.documentation="https://github.com/okoko/python-torch-docker"
LABEL org.opencontainers.image.source="https://github.com/okoko/python-torch-docker"
LABEL org.opencontainers.image.vendor="Software Consulting Kohtala Ltd"
LABEL org.opencontainers.image.licenses="(BSD-3 AND Python-2.0)"
LABEL org.opencontainers.image.title="PyTorch wheels"
