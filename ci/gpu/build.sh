#!/bin/bash
# Copyright (c) 2022, NVIDIA CORPORATION.
##############################################
# kvikIO GPU build and test script for CI    #
##############################################
set -e
NUMARGS=$#
ARGS=$*

# Arg parsing function
function hasArg {
    (( ${NUMARGS} != 0 )) && (echo " ${ARGS} " | grep -q " $1 ")
}

# Set path and build parallel level
export PATH=/opt/conda/bin:/usr/local/cuda/bin:$PATH
export PARALLEL_LEVEL=${PARALLEL_LEVEL:-4}

# Set home to the job's workspace
export HOME="$WORKSPACE"

# Switch to project root; also root of repo checkout
cd "$WORKSPACE"

# Determine CUDA release version
export CUDA_REL=${CUDA_VERSION%.*}

# Parse git describe
export GIT_DESCRIBE_TAG=`git describe --tags`
export MINOR_VERSION=`echo $GIT_DESCRIBE_TAG | grep -o -E '([0-9]+\.[0-9]+)'`
unset GIT_DESCRIBE_TAG

################################################################################
# SETUP - Check environment
################################################################################

gpuci_logger "Check environment variables"
env

gpuci_logger "Check GPU usage"
nvidia-smi

gpuci_logger "Activate conda env"
. /opt/conda/etc/profile.d/conda.sh
conda activate rapids

gpuci_logger "Check compiler versions"
python --version
$CC --version
$CXX --version

gpuci_logger "Check conda environment"
conda info
conda config --show-sources
conda list --show-channel-urls

################################################################################
# TEST - Run py.test for kvikio
################################################################################

gpuci_logger "Build and install libkvikio and kvikio"
cd "${WORKSPACE}"
export CONDA_BLD_DIR="${WORKSPACE}/.conda-bld"
gpuci_mamba_retry install -c conda-forge boa
gpuci_conda_retry mambabuild --croot ${CONDA_BLD_DIR} conda/recipes/libkvikio
gpuci_conda_retry mambabuild --croot ${CONDA_BLD_DIR} conda/recipes/kvikio --python=$PYTHON -c "${CONDA_BLD_DIR}"
gpuci_mamba_retry install -c "${CONDA_BLD_DIR}" libkvikio kvikio

cd "$WORKSPACE/python"
gpuci_logger "Python py.test for kvikio"
py.test -n 6 --cache-clear --basetemp="$WORKSPACE/cudf-cuda-tmp" --junitxml="$WORKSPACE/junit-kvikio.xml" -v

if [ -n "${CODECOV_TOKEN}" ]; then
    codecov -t $CODECOV_TOKEN
fi

return ${EXITCODE}
