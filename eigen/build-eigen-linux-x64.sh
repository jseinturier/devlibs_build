#!/bin/bash

# Clone and build Eigen C++ library from official Git repository.
# 
# This installation script needs that Git binaries are presents within PATH
# Git can be downloaded from https://git-scm.com/downloads
# 
# CMake is also needed and its binaries have to be pointed by PATH variable.
# CMake can be downloaded from https://cmake.org
#

echo "Eigen build"

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

gittag=3.4.0

rootdir=${script_directory}/${gittag}

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
echo "Getting Eigen from git repository"
if [ ! -d "${gitdir}" ]; then
  echo '  Cloning Eigen'
  mkdir ${gitdir}
  pushd ${gitdir} > /dev/null
  git clone -b ${gittag} --single-branch --depth 1 "https://gitlab.com/libeigen/eigen.git"
  popd > /dev/null
else
  echo "${gitdir} already exists, using these sources."
  echo "Remove the directory to perform a clean download."
fi

if [ -d "${builddir}" ]; then
  rm -rf ${builddir}
fi

mkdir -p ${builddir}
mkdir -p ${builddir}/eigen

if [ -d "${installdir}" ]; then
  rm -rf "${installdir}"
fi

mkdir -p "${installdir}/eigen"

echo
echo "CMAKE processing"

echo "  Running CMake (see ${logfile} for details)"

pushd ${builddir}/eigen > /dev/null

CMAKE_CONFIG_GENERATOR="Unix Makefiles"

CMAKE_OPTIONS=""

echo "    CMake options:"
echo "      General: ${CMAKE_OPTIONS}"

cmake -G"${CMAKE_CONFIG_GENERATOR}" ${CMAKE_OPTIONS} -DCMAKE_INSTALL_PREFIX=${installdir}/eigen ${gitdir}/eigen 1>>${logfile} 2>>${logfile}

echo "  Building"
make -j$(nproc) 1>>${logfile} 2>>${logfile}
make install 1>>${logfile} 2>>${logfile}

popd

echo "  Installing to ${rootdir}"
cp -r ${installdir}/eigen/include ${rootdir}/include
cp -r ${installdir}/eigen/share ${rootdir}/share

echo "#!/bin/bash" > ${rootdir}/eigen_environment.sh
echo "export Eigen3_DIR=${rootdir}/share/eigen3/cmake" >> ${rootdir}/eigen_environment.sh
echo "export EIGEN3_INCLUDE_DIR=${rootdir}/include/eigen3" >> ${rootdir}/eigen_environment.sh

echo
echo "Cleaning temporary files"
rm -rf ${tmpdir}
mv build.log ${rootdir}/build.log

echo
echo "Build done"

echo
echo "Please update your environment variables as follows:"
echo
echo "  Eigen3_DIR=${rootdir}/share/eigen3/cmake"
echo "  EIGEN3_INCLUDE_DIR=${rootdir}/include/eigen3"
echo
echo "see ${rootdir}/eigen_environment.sh"



