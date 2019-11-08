ARG PYTHON=3.7.5
ARG TORCH=1.3.1
ARG NUMPY=1.17.3

FROM python:${PYTHON}

ARG TORCH
ARG NUMPY
RUN pip install --no-cache-dir torch==${TORCH} numpy==${NUMPY}

COPY README.md LICENSE /
