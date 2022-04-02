#!/bin/bash

# Clone and build OpenCV C++ library from official Git repository.
#
# This installation script needs that Git binaries are presents within PATH
# Git can be downloaded from https://git-scm.com/downloads
# 
# CMake is also needed and its binaries have to be pointed by PATH variable.
# CMake can be downloaded from https://cmake.org
#

echo "OpenCV build"

# Check if Git is available
if ! [ -x "$(command -v git)" ]; then
  echo 'Git command not found, please install git package'
  exit 1
fi

# Check if CMake is available
if ! [ -x "$(command -v cmake)" ]; then
  echo 'CMake command not found, please install CMake package'
  exit 1
fi

script_directory="$(cd "$( echo "${BASH_SOURCE[0]%/*}" )" && pwd )"

logfile=${script_directory}/build.log

gittag=4.5.5

rootdir=${script_directory}/${gittag}-cuda

tmpdir=${script_directory}/tmp

gitdir=${tmpdir}/git
builddir=${tmpdir}/build
installdir=${tmpdir}/install

if [ -d "${rootdir}" ]; then
  rm -rf "${rootdir}"
fi
mkdir -p ${rootdir}

if [ -d "${tmpdir}" ]; then
  rm -rf "${tmpdir}"
fi
mkdir -p ${tmpdir}

echo "  Using repository ${gitdir}"
echo "  Installing into ${rootdir}"

echo
echo "  Disabling Python wrapper build"
PYTHON_CMAKE="-DBUILD_opencv_python:BOOL=OFF -DBUILD_opencv_python2:BOOL=OFF -DBUILD_opencv_python3:BOOL=OFF"

echo
echo "  Disabling Java wrapper build"
JAVA_CMAKE="-DBUILD_JAVA:BOOL=OFF -DBUILD_opencv_java:BOOL=OFF -DBUILD_opencv_java_bindings_generator:BOOL=OFF"


#TBB integration
TBBROOT=""
TBB_TARGET_ARCH=intel64

TBB_ARCH_PLATFORM="${TBB_TARGET_ARCH}"
TBB_BIN_DIR="${TBBROOT}/bin"
TBB_BIN_DIRS="${TBBROOT}/include"
TBB_LIB_DIR="${TBBROOT}/lib/${TBB_TARGET_ARCH}"
TBB_STDDEF_PATH="${TBB_BIN_DIRS}/tbb/tbb_stddef.h"
CUDA_GENERATION="Volta"

#Checking CPU
cpu_constructor=`cat /proc/cpuinfo | grep "vendor_id" | tr -d "[:blank:]"|cut -f2 -d':'`

IPP_INTEGRATION="-DUSE_IPP:BOOL=ON"

# Checking CUDA
# Check if CMake is available
if ! [ -x "$(command -v nvcc)" ]; then
  echo '  CUDA SDK not found, it can be installed from https://developper.nvidia.com/cuda-downloads'
  echo '  No CUDA integration available for OpenCV'
  CUDA_INTEGRATION="-DWITH_CUDA:BOOL=OFF -DCUDA_FAST_MATH:BOOL=OFF -DWITH_CUBLAS:BOOL=OFF"
else
  echo '  CUDA Toolkit found, enabling CUDA for OpenCV'
  CUDA_INTEGRATION="-DWITH_CUDA:BOOL=ON -DCUDA_FAST_MATH:BOOL=ON -DWITH_CUBLAS:BOOL=ON -DWITH_CUFFT:BOOL=ON -DCUDA_GENERATION=${CUDA_GENERATION} -DCUDA_ARCH_BIN=7.2 -DCUDA_ARCH_PTX=7.2"
fi

echo
echo "Getting OpenCV from git repository"
if [ ! -d "${gitdir}" ]; then
  echo '  Cloning OpenCV from https://github.com/opencv/opencv.git'
  mkdir ${gitdir}
  pushd ${gitdir} > /dev/null
  git clone -b ${gittag} --single-branch --depth 1 "https://github.com/opencv/opencv.git"
  popd > /dev/null
else
  echo "${gitdir} already exists, using these sources."
  echo "Remove the directory to perform a clean download."
fi

if [ ! -d "${gitdir}/opencv_contrib" ]; then
  echo '  Cloning OpenCV Contrib from https://github.com/opencv/opencv_contrib.git'
  pushd ${gitdir} > /dev/null
  git clone -b ${gittag} --single-branch --depth 1 "https://github.com/opencv/opencv_contrib.git"
  popd > /dev/null
else
  echo "${gitdir} already exists, using these sources."
  echo "Remove the directory to perform a clean download."
fi

if [ -d "${builddir}" ]; then
  rm -rf ${builddir}
fi

mkdir -p ${builddir}
mkdir -p ${builddir}/opencv
mkdir -p ${builddir}/opencvv_contrib

if [ -d "${installdir}" ]; then
  rm -rf "${installdir}"
fi
mkdir -p "${installdir}/opencv"

echo
echo "CMAKE processing"

echo "  Running CMake (see ${logfile} for details)"

pushd ${builddir}/opencv > /dev/null

CMAKE_CONFIG_GENERATOR="Unix Makefiles"

CMAKE_OPTIONS="${PYTHON_CMAKE} ${JAVA_CMAKE} -DBUILD_PERF_TESTS:BOOL=OFF -DBUILD_TESTS:BOOL=OFF -DENABLE_FAST_MATH=1 -DBUILD_DOCS:BOOL=OFF -DBUILD_EXAMPLES:BOOL=OFF -DBUILD_opencv_world:BOOL=OFF -DBUILD_SHARED_LIBS:BOOL=ON -DINSTALL_CREATE_DISTRIB:BOOL=ON -DOPENCV_ENABLE_NONFREE:BOOL=ON"

echo "    CMake options:"
echo "      General: ${CMAKE_OPTIONS}"
echo "      IPP integration : ${IPP_INTEGRATION}"
echo "      TBB integration : ${TBB_INTEGRATION}"
echo "      CUDA integration: ${CUDA_INTEGRATION}"

cmake -G"${CMAKE_CONFIG_GENERATOR}" ${CMAKE_OPTIONS} ${IPP_INTEGRATION} ${TBB_INTEGRATION} ${CUDA_INTEGRATION} -DOPENCV_EXTRA_MODULES_PATH=${gitdir}/opencv_contrib/modules -DCMAKE_INSTALL_PREFIX=${rootdir} ${gitdir}/opencv 1>>${logfile} 2>>${logfile}

if [ $? -eq 0 ]; then
    echo "  CMAKE completed successfully."
else
    echo "* CMAKE failed, see log."
    echo
    echo "Cannot build library due to previous errors."
    exit 1
fi

echo "  Building"
make -j$(nproc) 1>>${logfile} 2>>${logfile}

if [ $? -eq 0 ]; then
    echo "  MAKE build completed successfully."
else
    echo "* MAKE build failed, see log."
    echo
    echo "Cannot build library due to previous errors."
    exit 1
fi

echo "  Installing"
make install 1>>${logfile} 2>>${logfile}

if [ $? -eq 0 ]; then
    echo "  MAKE instal completed successfully."
else
    echo "* MAKE install failed, see log."
    echo
    echo "Cannot install library due to previous errors."
    exit 1
fi

popd

echo "#!/bin/bash" > ${rootdir}/opencv_environment.sh
echo "export OpenCV_DIR=${rootdir}" >> ${rootdir}/opencv_environment.sh
echo "export OPENCV_INCDIR=${rootdir}/include/opencv4" >> ${rootdir}/opencv_environment.sh
echo "export OPENCV_BINDIR=${rootdir}/lib" >> ${rootdir}/opencv_environment.sh
echo "export OPENCV_LIBDIR=${rootdir}/lib" >> ${rootdir}/opencv_environment.sh

echo
echo "Cleaning temporary files"
rm -rf ${tmpdir}
mv build.log ${rootdir}/build.log

echo
echo "OpenCV installation done."

echo
echo "Please update your environment variables as follows:"
echo "  OpenCV_DIR=${rootdir}"
echo "  OPENCV_INCDIR=${rootdir}/include/opencv4"
echo "  OPENCV_BINDIR=${rootdir}/lib"
echo "  OPENCV_LIBDIR=${rootdir}/lib"
echo
echo "see ${rootdir}/opencv_environment.sh"

