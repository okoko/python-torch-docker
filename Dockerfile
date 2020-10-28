ARG PYTHON=3.7.9
ARG TORCH=1.7.0
ARG TORCH_REQUIREMENT="torch==${TORCH}"
ARG NUMPY=1.19.2
ARG CREATED
ARG SOURCE_COMMIT

FROM python:${PYTHON}

ARG TORCH_REQUIREMENT
ARG NUMPY
RUN pip install --no-cache-dir ${TORCH_REQUIREMENT} numpy==${NUMPY}

COPY README.md LICENSE /

# nvidia-docker plugin uses these environment variables to provide services
# into the container. See https://github.com/NVIDIA/nvidia-docker/wiki/Usage
ENV NVIDIA_VISIBLE_DEVICES "all"
ENV NVIDIA_DRIVER_CAPABILITIES "all"

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

ENV TORCH_VERSION="${TORCH}"
ENV NUMPY_VERSION="${NUMPY}"
