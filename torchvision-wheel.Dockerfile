# Compatibility matrix for torch+torchvision: https://github.com/pytorch/vision
ARG TORCHVISION_VERSION=0.16.2
ARG PYTORCH_VERSION=2.1.2
ARG TORCH_WHEEL_SOURCE="scratch"
ARG ARM_BASE_IMAGE=nvcr.io/nvidia/l4t-cuda:12.2.12-devel


# Using variable in RUN --mount=from gives error 'from' doesn't support variable expansion, define alias stage instead
FROM ${TORCH_WHEEL_SOURCE} as torch-wheel-image


# Builder stage for x86 wheel, just a dummy for now
FROM scratch as amd64

# Builder stage for arm64 wheel
FROM ${ARM_BASE_IMAGE} as arm64

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

# Deprecation of some packages in setuptools version >70, so we downgrade to older version
# https://github.com/aws-neuron/aws-neuron-sdk/issues/893
RUN pip3 uninstall -y setuptools && pip3 install setuptools==69.5.1
RUN pip3 uninstall -y numpy && pip3 install numpy

ARG PYTORCH_VERSION

# Install PyTorch dependency
RUN --mount=from=torch-wheel-image,src=/,target=/opt/ \
    <<NUR
    set -ex \
    # If any wheel files exist, install from those, otherwise install from PyPi
    if ls /opt/*.whl 1> /dev/null 2>&1
    then
        TORCH_INSTALL="/opt/*.whl"
    else
        TORCH_INSTALL="torch==${PYTORCH_VERSION}"
    fi
    pip3 install --no-cache-dir ${TORCH_INSTALL}
    pip freeze
NUR

WORKDIR /opt/torchvision

ARG TORCHVISION_VERSION

RUN git clone --branch "v${TORCHVISION_VERSION}" --recursive --depth=1 https://github.com/pytorch/vision /opt/torchvision

RUN git checkout "v${TORCHVISION_VERSION}"

# Both CUDA_HOME & TORCH_CUDA_ARCH_LIST are needed
RUN cd /opt/torchvision && \
    export FORCE_CUDA=1 && \
    export CUDA_HOME=/usr/local/cuda-12.2 && \
    export TORCH_CUDA_ARCH_LIST="7.2;8.7" && \
    export TORCHVISION_USE_PNG=1 && \
    export TORCHVISION_USE_JPEG=1 && \
    python3 setup.py --verbose bdist_wheel --dist-dir /

RUN pip3 install auditwheel

RUN apt install -y patchelf

# Needed to correctly link dynamic libraries in the wheel
# https://github.com/pytorch/vision/blob/main/packaging/wheel/relocate.py
RUN cd /opt/torchvision/packaging/wheel/ && \
  python3 relocate.py

WORKDIR /home

# RUN pip3 install --no-cache-dir --verbose /opt/torchvision/dist/*.whl


# Alias to copy files from in next stage
FROM ${TARGETARCH} as wheels

# We only want to store the wheel in the final image
FROM scratch as wheel-container

COPY --from=wheels /*.whl /
