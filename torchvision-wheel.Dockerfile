ARG TORCHVISION_VERSION=release/0.16
ARG BASE_IMAGE=nvcr.io/nvidia/l4t-cuda:12.2.12-devel

FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

RUN apt-get update && \
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
      libpng-dev \
      libjpeg-turbo8-dev \
      zlib1g-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

RUN apt-get update && apt-get install python3.11-distutils

RUN wget https://bootstrap.pypa.io/get-pip.py

RUN python3.11 get-pip.py

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    update-alternatives --set python3 /usr/bin/python3.11 && \
    update-alternatives --install /usr/bin/pip pip /usr/local/bin/pip3.11 1 && \
    update-alternatives --set pip /usr/local/bin/pip3.11

RUN pip3 uninstall -y numpy && pip3 install numpy

COPY torch-wheel/torch-*.whl /opt/

RUN pip3 install --verbose /opt/torch-*.whl

WORKDIR /opt/torchvision

ARG TORCHVISION_VERSION

RUN git clone --branch ${TORCHVISION_VERSION} --recursive --depth=1 https://github.com/pytorch/vision /opt/torchvision

RUN git checkout ${TORCHVISION_VERSION}

RUN cd

# Both CUDA_HOME & TORCH_CUDA_ARCH_LIST are needed
RUN cd /opt/torchvision && \
    export FORCE_CUDA=1 && \
    export CUDA_HOME=/usr/local/cuda-12.2 && \
    export TORCH_CUDA_ARCH_LIST="7.2;8.7" && \
    export TORCHVISION_USE_PNG=1 && \
    export TORCHVISION_USE_JPEG=1 && \
    python3  setup.py --verbose bdist_wheel --dist-dir /opt/torchvision/dist

RUN pip3 install auditwheel

RUN apt install -y patchelf

RUN cd /opt/torchvision/packaging/wheel/ && \
  python3 relocate.py

WORKDIR /home

# RUN pip3 install --no-cache-dir --verbose /opt/torchvision/dist/*.whl
