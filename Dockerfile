ARG PYTHON=3.7.5
ARG TORCH=1.3.1
ARG TORCH_REQUIREMENT="torch==${TORCH}"
ARG NUMPY=1.17.4
ARG CREATED
ARG SOURCE_COMMIT

FROM python:${PYTHON}

ARG TORCH_REQUIREMENT
ARG NUMPY
RUN pip install --no-cache-dir ${TORCH_REQUIREMENT} numpy==${NUMPY}

COPY README.md LICENSE /

ARG PYTHON
ARG TORCH
ARG CREATED
ARG SOURCE_COMMIT
# See https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL fi.okoko.image.authors="Marko Kohtala <marko.kohtala@okoko.fi>"
LABEL fi.okoko.image.url="https://hub.docker.com/r/okoko/python-torch"
LABEL fi.okoko.image.documentation="https://github.com/okoko/python-torch-docker"
LABEL fi.okoko.image.source="https://github.com/okoko/python-torch-docker"
LABEL fi.okoko.image.vendor="Software Consulting Kohtala Ltd"
LABEL fi.okoko.image.licenses="(BSD-3 AND Python-2.0)"
LABEL fi.okoko.image.title="Python with preinstalled Torch"
LABEL fi.okoko.image.description="Python with preinstalled Torch"
LABEL fi.okoko.image.created="${CREATED}"
LABEL fi.okoko.image.version="${TORCH}-${PYTHON}"
LABEL fi.okoko.image.revision="${SOURCE_COMMIT}"
LABEL fi.okoko.image.version.python="${PYTHON}"
LABEL fi.okoko.image.version.torch="${TORCH}"
LABEL fi.okoko.image.version.numpy="${NUMPY}"

ENV TORCH_VERSION="${TORCH}"
ENV NUMPY_VERSION="${NUMPY}"
