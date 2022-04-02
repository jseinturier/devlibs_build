#!/bin/bash

# Clone and build Boost C++ library from official Git repository.
# 
# This installation script needs that Git binaries are presents within PATH
# Git can be downloaded from https://git-scm.com/downloads
#

echo "Boost build"

# Check if Git is available
if ! [ -x "$(command -v git)" ]; then
  echo 'Git command not found, please install git package'
  exit 1
fi

script_directory="$(cd "$( echo "${BASH_SOURCE[0]%/*}" )" && pwd )"

logfile=${script_directory}/build.log

gittag=boost-1.78.0

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
echo "Getting Boost from git repository"
if [ ! -d "${gitdir}" ]; then
  echo '  Cloning Boost'
  mkdir ${gitdir}
  pushd ${gitdir} > /dev/null
  git clone -b ${gittag} --recurse-submodules --single-branch --depth 1 "https://github.com/boostorg/boost.git"
  popd > /dev/null
else
  echo "${gitdir} already exists, using these sources."
  echo "Remove the directory to perform a clean download."
fi

if [ -d "${builddir}" ]; then
  rm -rf ${builddir}
fi

mkdir -p ${builddir}
mkdir -p ${builddir}/boost

if [ -d "${installdir}" ]; then
  rm -rf "${installdir}"
fi
mkdir -p "${installdir}/${gittag}"

pushd ${gitdir}/boost
./bootstrap.sh cxxflags="-arch arm64" cflags="-arch arm64" --without-libraries=python 1>>${logfile} 2>>${logfile}

if [ $? -eq 0 ]; then
    echo "  bootstrap completed successfully."
else
    echo "* bootstrap failed, see log."
    echo
    echo "Cannot build Boost library due to previous errors."
    exit 1
fi

./b2 install --prefix=${installdir}/${gittag} --exec-prefix=${installdir}/${gittag} link=shared architecture=arm address-model=64 threading=multi --variant=debug,release 1>>${logfile} 2>>${logfile}
popd

if [ $? -eq 0 ]; then
    echo "  B2 completed successfully."
else
    echo "* B2 failed, see log."
    echo
    echo "Cannot build Boost library due to previous errors."
    exit 1
fi

echo
echo "Installing to ${rootdir}"
cp -r ${installdir}/${gittag}/include ${rootdir}/include
cp -r ${installdir}/${gittag}/lib ${rootdir}/lib

#mkdir -p "${installdir}/${gittag}/include_nover"
#cp -r ${installdir}/${gittag}/include/${gittag}/* ${rootdir}/include_nover

echo "#!/bin/bash" > ${rootdir}/boost_environment.sh
echo "export BOOST_ROOT=${rootdir}" >> ${rootdir}/boost_environment.sh
echo "export BOOST_INCLUDEDIR=${rootdir}/include" >> ${rootdir}/boost_environment.sh
echo "export BOOST_LIBRARYDIR=${rootdir}/lib" >> ${rootdir}/boost_environment.sh

echo
echo "Cleaning temporary files"
rm -rf ${tmpdir}
mv build.log ${rootdir}/build.log

echo
echo "Boost build success"
echo
echo "Please update your environment variables as follows:"
echo "  BOOST_ROOT=${rootdir}"
echo "  BOOST_INCLUDEDIR=${rootdir}/include"
echo "  BOOST_LIBRARYDIR=${rootdir}/lib"
echo
echo "Environment variable can be found within ${rootdir}/boost_environment.sh file"


