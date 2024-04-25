ARG PYTORCH_BUILD_VERSION=2.1.2
ARG BASE_IMAGE=nvcr.io/nvidia/l4t-cuda:12.2.12-devel

# Builder stage for x86 wheel, just a dummy for now
FROM scratch as amd64


# Alias to temporarily copy wheel from.
# TODO: Remove after we can build arm wheel on github runners
FROM opukka/torch-wheels:${PYTORCH_BUILD_VERSION} as wheels-source

# TODO: This is a temporary solution where we just copy the wheels from opukka/torch-wheels
# Actual wheel building steps are commented out, return this once we have arm/self-hosted runner available
# Builder stage for arm64 wheel
FROM ${BASE_IMAGE} as arm64

# TODO: Remove after we can build arm wheel on github runners
COPY --from=wheels-source /*.whl /

# ENV DEBIAN_FRONTEND=noninteractive

# ARG PYTORCH_BUILD_VERSION
# ARG PYTORCH_BUILD_NUMBER=1

# RUN apt-get update && apt-get install -y software-properties-common
# RUN add-apt-repository ppa:deadsnakes/ppa

# RUN --mount=type=cache,target=/var/cache/apt,id=bookworm-/var/cache/apt \
#     --mount=type=cache,target=/var/lib/apt,sharing=locked,id=bookworm-/var/lib/apt \
#     rm -f /etc/apt/apt.conf.d/docker-clean && \
#     echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
#     apt-get update && \
#     apt-get install -y --no-install-recommends \
#             libopenblas-dev \
#             libopenmpi-dev \
#             openmpi-bin \
#             openmpi-common \
#             gfortran \
#             libomp-dev \
#             git \
#             python3.11 \
#             python3.11-dev \
#             build-essential \
#             cmake \
#     && rm -rf /var/lib/apt/lists/* \
#     && apt-get clean

# RUN apt-get update && apt-get install python3.11-distutils 
# RUN wget https://bootstrap.pypa.io/get-pip.py 
# RUN python3.11 get-pip.py

# # Switch from py 3.10 (default on base image) to 3.11. This is needed for pytorch that works with 3.11
# RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
#     update-alternatives --set python3 /usr/bin/python3.11 && \
#     update-alternatives --install /usr/bin/pip pip /usr/local/bin/pip3.11 1 && \
#     update-alternatives --set pip /usr/local/bin/pip3.11

# RUN pip3 uninstall -y numpy && pip3 install numpy

# RUN git clone --branch v${PYTORCH_BUILD_VERSION} --depth=1 --recursive https://github.com/pytorch/pytorch /tmp/pytorch

# # Build PyTorch wheel for Jetson  
# # TORCH_CUDA_ARCH_LIST: Xavier = 7.2, Orin = 8.7
# RUN --mount=type=cache,target=/opt/ccache \
#     cd /tmp/pytorch && \
#     export USE_NCCL=0 && \
#     export USE_QNNPACK=0 && \
#     export USE_PYTORCH_QNNPACK=0 && \
#     export USE_NATIVE_ARCH=1 && \
#     export USE_DISTRIBUTED=1 && \
#     export USE_TENSORRT=0 && \
#     export TORCH_CUDA_ARCH_LIST="7.2;8.7" && \
#     export PYTHON_VERSION=3.11 && \
#     pip3 install -r requirements.txt && \
#     pip3 install --no-cache-dir scikit-build ninja && \
#     python3 setup.py bdist_wheel && \
# # TODO: Let's copy the wheels 
#     cp dist/*.whl /opt && \
#     rm -rf /tmp/pytorch


# Alias to copy files from in next stage
FROM ${TARGETARCH} as wheels

# We only want to store the wheel in the final image
FROM scratch as wheel-container

COPY --from=wheels /*.whl /
