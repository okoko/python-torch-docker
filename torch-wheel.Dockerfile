ARG PYTORCH_BUILD_VERSION=2.9.1
ARG CUDA_VERSION=12.6
ARG PYTHON_VERSION=3.14

# Looked up from https://github.com/pytorch/pytorch/actions/workflows/generated-linux-binary-manywheel-nightly.yml
FROM --platform=linux/amd64 pytorch/manylinux2_28-builder:cuda12.6 AS build-amd64
# https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#compute-capability
# https://developer.nvidia.com/cuda/gpus
# Default x86 TORCH_CUDA_ARCH_LIST='5.0;6.0;7.0;7.5;8.0;8.6;9.0;'
# CCDocGPU1 runs 2080 7.5, servers A16 8.6
# CUDA 12.6 supports up to compute capability 9.0
# CUDA 12.8 dropped support for compute capabilities 5.0;6.0;7.0, added 10.0
ENV TORCH_CUDA_ARCH_LIST='7.5;8.0;8.6;9.0;'

# Looked up from https://github.com/pytorch/pytorch/actions/workflows/generated-linux-aarch64-binary-manywheel-nightly.yml
FROM --platform=linux/arm64 pytorch/manylinuxaarch64-builder:cuda12.6 AS build-arm64
# TORCH_CUDA_ARCH_LIST: Xavier = 7.2, Orin = 8.7
ENV TORCH_CUDA_ARCH_LIST='7.2;8.7'

# Builder stage for arm64 wheel
FROM build-${TARGETARCH} AS build

ARG PYTORCH_BUILD_VERSION
RUN git clone --branch v${PYTORCH_BUILD_VERSION} --depth=1 --recursive https://github.com/pytorch/pytorch /pytorch
ARG CUDA_VERSION
ENV CUDA_VERSION=${CUDA_VERSION}
ARG PYTHON_VERSION
ENV PYTHON_VERSION=${PYTHON_VERSION}

COPY torch-wheel.sh /

FROM build AS wheels
# Build PyTorch wheel
ARG PYTORCH_BUILD_NUMBER=1
RUN --mount=type=cache,target=/opt/ccache \
    <<NUR
    . /torch-wheel.sh
    find -name '*.whl' -ls
    # cp dist/*.whl /
    # rm -rf /pytorch
NUR

# We only want to store the wheel in the final image
FROM scratch AS wheel-container

COPY --from=wheels /artifacts/*.whl /

LABEL org.opencontainers.image.authors="Marko Kohtala <marko.kohtala@okoko.fi>"
LABEL org.opencontainers.image.url="https://hub.docker.com/r/okoko/python-torch"
LABEL org.opencontainers.image.documentation="https://github.com/okoko/python-torch-docker"
LABEL org.opencontainers.image.source="https://github.com/okoko/python-torch-docker"
LABEL org.opencontainers.image.vendor="Software Consulting Kohtala Ltd"
LABEL org.opencontainers.image.licenses="(BSD-3 AND Python-2.0)"
LABEL org.opencontainers.image.title="PyTorch wheels"
