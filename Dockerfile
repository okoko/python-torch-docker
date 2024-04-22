# syntax=docker/dockerfile:1.4

ARG PYTHON=3.11.7
ARG TORCH=2.1.2
ARG TORCH_REQUIREMENT="torch==${TORCH}"
ARG EXTRA_INDEX_URL
# ARG TORCH_WHEEL_IMAGE="okoko/torch-wheels"
ARG TORCH_WHEEL_SOURCE="okoko/torch-wheels:2.1.2"
## wheel_source_repo + wheel_source_tag
## käsittele cpu keissi
#ARG TORCH_WHEEL_SOURCE="${TORCH_WHEEL_IMAGE}:${TORCH}"
ARG CREATED
ARG SOURCE_COMMIT
ARG CONSTRAINTS=constraints.txt

FROM ${TORCH_WHEEL_SOURCE} as wheel-image

FROM python:${PYTHON}

RUN --mount=type=cache,target=/var/cache/apt,id=bookworm-/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=bookworm-/var/lib/apt \
    <<NUR
    set -ex
# To keep cache of downloaded .debs, replace docker configuration
    rm -f /etc/apt/apt.conf.d/docker-clean
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
    apt-get update
    DEBIAN_FRONTEND=noninteractive \
    apt-get upgrade -y --no-install-recommends
NUR

COPY README.md LICENSE /

# COPY --from=opukka/torch-wheels /torch-2.1.1-cp311-cp311-linux_aarch64.whl /torch-2.1.2-cp311-cp311-linux_aarch64.whl /
# TODO: copy wheel pushed by gh actions instead
# COPY --from=opukka/torch-wheels /torch*.whl /

ARG CONSTRAINTS
ARG TORCH_REQUIREMENT
ARG EXTRA_INDEX_URL
ARG TORCH_WHEEL_SOURCE
ARG TARGETPLATFORM

# RUN --mount=src=${CONSTRAINTS},target=/tmp/constraints.txt \
#  pip install --no-cache-dir \
#  -c /tmp/constraints.txt \
#  ${EXTRA_INDEX_URL:+--extra-index-url ${EXTRA_INDEX_URL}} \
#  ${TORCH_REQUIREMENT}

# Extra dependencies needed to run pytorch on Jetson
# Retreived from: https://github.com/dusty-nv/jetson-containers/blob/master/packages/pytorch/Dockerfile
ARG ARM64_EXTRA_DEPS="libopenblas-dev libopenmpi-dev openmpi-common openmpi-bin gfortran libomp-dev"


RUN --mount=src=${CONSTRAINTS},target=/tmp/constraints.txt \
    --mount=from=wheel-image,src=/,target=/tmp/torch-wheels \
    case ${TARGETPLATFORM} in \
        # For arm64 install torch from custom wheel, plus some extra dependencies
        "linux/arm64") TORCH_INSTALL="/tmp/torch-wheels/*.whl"; \
        # TODO: Move these to RUN command above or to consumer image
                        apt-get update && apt-get install -y ${ARM64_EXTRA_DEPS} \
                        && rm -rf /var/lib/apt/lists/* \
                        && apt-get clean \
                        ;; \
        # For x86 install official torch distribution from PyPi
        *)             TORCH_INSTALL=${TORCH_REQUIREMENT} \
                        ;; \
    esac && \
    pip install --no-cache-dir \
    -c /tmp/constraints.txt \
    ${EXTRA_INDEX_URL:+--extra-index-url ${EXTRA_INDEX_URL}} \
    ${TORCH_INSTALL}


# RUN rm /torch-2.1.1-cp311-cp311-linux_aarch64.whl /torch-2.1.2-cp311-cp311-linux_aarch64.whl
# RUN rm /torch*.whl

# nvidia-docker plugin uses these environment variables to provide services
# into the container. See https://github.com/NVIDIA/nvidia-docker/wiki/Usage
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/user-guide.html#driver-capabilities
ENV NVIDIA_VISIBLE_DEVICES "all"
ENV NVIDIA_DRIVER_CAPABILITIES "compute,utility"
# libnvidia-ml.so location on k8s that does not run ldconfig
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64

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
LABEL org.opencontainers.image.torchWheelSource="${TORCH_WHEEL_SOURCE}"
