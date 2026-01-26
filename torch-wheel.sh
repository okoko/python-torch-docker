#!/bin/bash

set -ex
export PYTORCH_ROOT=/pytorch
export PACKAGE_TYPE=manywheel
export DESIRED_CUDA=cu${CUDA_VERSION/./}
export GPU_ARCH_VERSION=$CUDA_VERSION
export GPU_ARCH_TYPE=cuda
export DESIRED_PYTHON=$PYTHON_VERSION
export BUILD_ENVIRONMENT="manywheel-cuda"
export LIBTORCH_VARIANT=
export PYTORCH_FINAL_PACKAGE_DIR=/artifacts
export SKIP_ALL_TESTS=1
cd $PYTORCH_ROOT
export BINARY_ENV_FILE=/tmp/env
.circleci/scripts/binary_populate_env.sh
source ${BINARY_ENV_FILE}
# .ci/manywheel/build_cuda.sh makes some decisions we like to change, but this is looked up from there
# https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/
export TORCH_NVCC_FLAGS="-Xfatbin -compress-all"  # CUDA 12 and 13
export TH_BINARY_BUILD=1
export USE_STATIC_CUDNN=0  # CUDA 12 and 13
export INSTALL_TEST=0 # dont install test binaries into site-packages
export USE_CUSPARSELT=1
export USE_CUFILE=1

ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
    export BLAS=NVPL
    export USE_MKLDNN=1
    export USE_MKLDNN_ACL=1
    export ACL_ROOT_DIR=/acl
    # gcc -march=native -Q --help=target on the AGX Orin Devkit gave the native arch, define it explicitly for compilation on ARM servers
    export USE_NATIVE_ARCH=0
    export CFLAGS="-march=armv8.2-a+crypto+fp16+rcpc+dotprod+flagm+pauth"
    export CXXFLAGS="-march=armv8.2-a+crypto+fp16+rcpc+dotprod+flagm+pauth"
else
    export USE_NATIVE_ARCH=1
fi
# Use nvidia libs from pypi
CUDA_RPATHS=(
    '$ORIGIN/../../nvidia/cudnn/lib'
    '$ORIGIN/../../nvidia/nvshmem/lib'
    '$ORIGIN/../../nvidia/nccl/lib'
    '$ORIGIN/../../nvidia/cusparselt/lib'
    '$ORIGIN/../../nvidia/cublas/lib'
    '$ORIGIN/../../nvidia/cuda_cupti/lib'
    '$ORIGIN/../../nvidia/cuda_nvrtc/lib'
    '$ORIGIN/../../nvidia/cuda_runtime/lib'
    '$ORIGIN/../../nvidia/cufft/lib'
    '$ORIGIN/../../nvidia/curand/lib'
    '$ORIGIN/../../nvidia/cusolver/lib'
    '$ORIGIN/../../nvidia/cusparse/lib'
    '$ORIGIN/../../cusparselt/lib'
    '$ORIGIN/../../nvidia/nvtx/lib'
    '$ORIGIN/../../nvidia/cufile/lib'
)
CUDA_RPATHS=$(IFS=: ; echo "${CUDA_RPATHS[*]}")
export C_SO_RPATH=$CUDA_RPATHS':$ORIGIN:$ORIGIN/lib'
export LIB_SO_RPATH=$CUDA_RPATHS':$ORIGIN'
export FORCE_RPATH="--force-rpath"
export ATEN_STATIC_CUDA=0
export USE_CUDA_STATIC_LINK=0
export USE_CUPTI_SO=1

export USE_MAGMA=0
export USE_NCCL=0
export USE_QNNPACK=0
export USE_PYTORCH_QNNPACK=0
export USE_DISTRIBUTED=0
export USE_TENSORRT=0

source .ci/manywheel/build_common.sh
