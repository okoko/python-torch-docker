# syntax=docker/dockerfile:1.2

ARG PYTHON=3.9.7
ARG TORCH=1.9.0
ARG TORCH_REQUIREMENT="torch==${TORCH}"
ARG NUMPY=1.21.2
ARG CREATED
ARG SOURCE_COMMIT

FROM python:${PYTHON}

COPY README.md LICENSE /

ARG TORCH_REQUIREMENT
ARG NUMPY
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    pip install --no-cache-dir ${TORCH_REQUIREMENT} numpy==${NUMPY}

# nvidia-docker plugin uses these environment variables to provide services
# into the container. See https://github.com/NVIDIA/nvidia-docker/wiki/Usage
ENV NVIDIA_VISIBLE_DEVICES "all"
ENV NVIDIA_DRIVER_CAPABILITIES "all"
# libnvidia-ml.so location on k8s that does not run ldconfig
ENV LD_LIBRARY_PATH=/usr/local/nvidia/lib64

ENV TORCH_VERSION="${TORCH}"
ENV NUMPY_VERSION="${NUMPY}"
# Nvidia GPU device plugin on kubernetes mounts the driver here
ENV PATH=${PATH}:/usr/local/nvidia/bin

ARG PYTHON
ARG TORCH
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
LABEL org.opencontainers.image.version.numpy="${NUMPY}"
