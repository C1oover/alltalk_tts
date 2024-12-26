#!/usr/bin/env bash

set -e  # Exit on error

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

. ${SCRIPT_DIR}/docker/variables.sh

TTS_MODEL=xtts
CLEAN=false

# Parse arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --cuda-version)
      CUDA_VERSION="$2"
      shift
      ;;
    --python-version)
      PYTHON_VERSION="$2"
      shift
      ;;
    --tts_model)
      TTS_MODEL="$2"
      shift
      ;;
    --clean)
      CLEAN=true
      ;;
    *)
      printf '%s\n' "Invalid argument ($1)"
      exit 1
      ;;
  esac
  shift
done

# Create required build directories
mkdir -p ${SCRIPT_DIR}/docker/conda/build
mkdir -p ${SCRIPT_DIR}/docker/deepspeed/build
echo "Created build directories"

if [ "$CLEAN" = true ]; then
  rm -rf ${SCRIPT_DIR}/docker/conda/build
  rm -rf ${SCRIPT_DIR}/docker/deepspeed/build
  # Recreate directories after clean
  mkdir -p ${SCRIPT_DIR}/docker/conda/build
  mkdir -p ${SCRIPT_DIR}/docker/deepspeed/build
  echo "Cleaned and recreated build directories"  
fi

# Build conda environment
${SCRIPT_DIR}/docker/conda/build-conda-env.sh \
  --cuda-version ${CUDA_VERSION} \
  --python-version ${PYTHON_VERSION}

# Build DeepSpeed
${SCRIPT_DIR}/docker/deepspeed/build-deepspeed.sh \
  --python-version ${PYTHON_VERSION}

echo "Build preparation completed successfully"
echo "CUDA Version: ${CUDA_VERSION}"
echo "Python Version: ${PYTHON_VERSION}"
echo "TTS Model: ${TTS_MODEL}"