@echo on
@cls
@SETLOCAL EnableDelayedExpansion

@rem Clone and build OpenCV C++ library from official Git repository.
@rem 
@rem This installation script needs that Git binaries are presents within PATH
@rem Git for windows can be downloaded from https://gitforwindows.org
@rem 
@rem CMake for windows is also needed and its binaries have to be pointed by PATH variable.
@rem CMake for windows can be downloaded from https://cmake.org
@rem
@rem In order to build OpenCV, this script need an access to the devenv.exe command.
@rem this command is available if:
@rem   - This script is called from a Visual Studio Command Prompt (see https://docs.microsoft.com/en-us/dotnet/framework/tools/developer-command-prompt-for-vs)
@rem   - Before calling this script, the directory that contains devenv command is added to the PATH.
@rem If devenv is not accessible by this script, final build has to be performed from Visual Studio IDE.

@ECHO OpenCV build

@rem check if Git is available
@WHERE git >nul 2>nul
@IF NOT %ERRORLEVEL% EQU 0 (
  @ECHO Git command not found, please install Git for windows from https://gitforwindows.org
  @EXIT /B
)

@rem check if Git is available
@WHERE cmake >nul 2>nul
@IF NOT %ERRORLEVEL% EQU 0 (
  @ECHO CMake command not found, please install CMake for windows from https://cmake.org
  @EXIT /B
)

@SET local_repository=%~dp0tmp\git

@SET logfile=%~dp0build.log

@SET opencvtag=4.5.5
@SET opencvcontribtag=4.5.5

@SET rootdir=%~dp0!opencvtag!-cuda
@SET builddir=tmp\build
@SET instaldir=tmp\install

@IF NOT EXIST %rootdir% (
  @md %rootdir%
) ELSE (
  @rd /s /q %rootdir%
)

@ECHO   Installing to %rootdir%

@ECHO.
@ECHO   Disabling Python wrapper build
@SET PYTHON_CMAKE=-DBUILD_opencv_python:BOOL=OFF -DBUILD_opencv_python2:BOOL=OFF -DBUILD_opencv_python3:BOOL=OFF

@ECHO.
@ECHO   Disabling Java wrapper build
@SET JAVA_CMAKE=-DBUILD_JAVA:BOOL=OFF -DBUILD_opencv_java:BOOL=OFF -DBUILD_opencv_java_bindings_generator:BOOL=OFF


@SET VISUAL_STUDIO_VC=vc17
@SET CMAKE_GENERATOR="Visual Studio 17 2022"
@SET CMAKE_GENERATOR_TOOLSET="v143,host=x64"

@rem TBB integration
@SET TBBROOT=unknown
@SET TBB_TARGET_ARCH=unknown
@SET TBB_TARGET_VS=%VISUAL_STUDIO_VC%

@SET TBB_ARCH_PLATFORM=%TBB_TARGET_ARCH%\%TBB_TARGET_VS%
@SET TBB_BIN_DIR=%TBBROOT%\bin
@SET TBB_INCLUDE_DIRS=%TBBROOT%\include
@SET TBB_LIB_DIR=%TBBROOT%\lib\%TBB_TARGET_ARCH%\%TBB_TARGET_VS%
@SET TBB_STDDEF_PATH=%TBB_INCLUDE_DIRS%\tbb\tbb_stddef.h

@SET CUDA_ENABLED=1

@rem Checking platform constructor
@ECHO.
@ECHO Checking CPU
@wmic cpu get name /VALUE | findstr /i "intel" >nul 2>&1
@IF ERRORLEVEL 0 (
    @ECHO   Intel Architecture found, enabling TBB
) ELSE (
    @ECHO   No Intel Architecture found, disabling TBB
    @SET TBBROOT=
)

@IF EXIST %TBBROOT% (
    @ECHO   Integrating TBB from %TBBROOT%
    @SET TBB_INTEGRATION="-DWITH_TBB:BOOL=ON -DBUILD_TBB:BOOL=OFF -DTBB_ENV_INCLUDE:PATH=!TBB_INCLUDE_DIRS! -DTBB_ENV_LIB:FILEPATH=!TBB_LIB_DIR!/tbb.lib -DTBB_ENV_LIB_DEBUG:FILEPATH=!TBB_LIB_DIR!/tbb_debug.lib"
    @ECHO   CMAKE properties: !TBB_INTEGRATION!
) ELSE (
    @ECHO   No TBB library provided.
    @SET TBB_INTEGRATION=
)
    
@SET IPP_INTEGRATION=-DUSE_IPP:BOOL=ON

@IF %CUDA_ENABLED% EQU 1 (
  rem Checking GPU constructor 
  @ECHO.
  @ECHO Checking GPU
  @FOR /F "tokens=* skip=1" %%n IN ('WMIC path Win32_VideoController get Name ^| findstr "."') do @set GPU_NAME=%%n
  @ECHO %GPU_NAME% | findstr /i "intel" >nul 2>&1
  @IF ERRORLEVEL 0 (
    @ECHO   NVIDIA GPU Architecture found
    
    rem check if CUDA SDK is available
    @WHERE nvcc >nul 2>nul
    @IF NOT !ERRORLEVEL! EQU 0 (
      @ECHO   NVIDIA Cuda Toolkit not found, please install Cuda Toolkit for windows from https://developer.nvidia.com/cuda-toolkit
      @SET CUDA_INTEGRATION=-DWITH_CUDA:BOOL=OFF -DCUDA_FAST_MATH:BOOL=OFF -DWITH_CUBLAS:BOOL=OFF
    ) ELSE (
      @ECHO   NVIDIA Cuda Toolkit found
      @SET CUDA_INTEGRATION=-DWITH_CUDA:BOOL=ON -DWITH_CUBLAS:BOOL=ON -DWITH_CUFFT:BOOL=ON -DCUDA_FAST_MATH:BOOL=ON -DCUDA_ARCH_BIN="7.5"  -DCUDA_ARCH_PTX=7.5
    )
  ) ELSE (
    @ECHO   No NVIDIA GPU Architecture found, disabling CUDA
    @SET CUDA_INTEGRATION=-DWITH_CUDA:BOOL=OFF -DCUDA_FAST_MATH:BOOL=OFF -DWITH_CUBLAS:BOOL=OFF
  )
) ELSE (
  @ECHO CUDA is not enabled, set CUDA_ENABLED to 1 to enable
  @SET CUDA_INTEGRATION=-DWITH_CUDA:BOOL=OFF -DCUDA_FAST_MATH:BOOL=OFF -DWITH_CUBLAS:BOOL=OFF
)

@ECHO.
@ECHO Getting OpenCV from git repository
@IF EXIST %local_repository% (
  @ECHO   Updating opencv
) ELSE (
  @ECHO   Clonning opencv
  @mkdir %local_repository%
  @pushd %local_repository%
  git clone -b %opencvtag% --depth 1 --single-branch "https://github.com/opencv/opencv.git" >> %logfile% 2>&1
  @popd
)

@ECHO.
@ECHO Checking opencv_contrib git repository
@IF EXIST %local_repository%\opencv_contrib (
    @echo   Updating opencv_contrib
    @rem cd opencv_contrib
    @rem git pull --rebase https://github.com/opencv/opencv_contrib.git ${opencvcontribtag}
    @rem cd ..
) ELSE (
    @echo   Clonning opencv_contrib
    @pushd %local_repository%
    git clone -b %opencvcontribtag% --depth 1 --single-branch "https://github.com/opencv/opencv_contrib.git" >> %logfile% 2>&1
    @popd
)

@IF EXIST %builddir% (
  @rmdir %builddir%
)
@mkdir %builddir%
@mkdir %builddir%\opencv
    
@IF EXIST %instaldir% (
  @rmdir %instaldir%
)
@mkdir %instaldir%
@mkdir %instaldir%\opencv

@ECHO.
@ECHO CMAKE processing

@pushd %builddir%\opencv

@ECHO   Running CMAKE (see %logfile% for details)
@SET CMAKE_OPTIONS=%PYTHON_CMAKE% %JAVA_CMAKE% -DBUILD_PERF_TESTS:BOOL=OFF -DBUILD_TESTS:BOOL=OFF -DENABLE_FAST_MATH=1 -DOPENCV_ENABLE_NONFREE:BOOL=ON -DBUILD_DOCS:BOOL=OFF -DBUILD_EXAMPLES:BOOL=OFF -DBUILD_opencv_world:BOOL=OFF -DBUILD_SHARED_LIBS:BOOL=ON -DINSTALL_CREATE_DISTRIB:BOOL=ON

@ECHO   CMake options:
@ECHO     General: %CMAKE_OPTIONS%
@ECHO     Ipp integration : %IPP_INTEGRATION%
@ECHO     TBB integration : %TBB_INTEGRATION%
@ECHO     CUDA integration: %CUDA_INTEGRATION%

@cmake -G%CMAKE_GENERATOR% -T%CMAKE_GENERATOR_TOOLSET% %CMAKE_OPTIONS% %IPP_INTEGRATION% %TBB_INTEGRATION% %CUDA_INTEGRATION% -DOPENCV_EXTRA_MODULES_PATH=%local_repository%\opencv_contrib\modules -DCMAKE_INSTALL_PREFIX=%rootdir% %local_repository%\opencv > %logfile% 2>&1

@ECHO   Running CMAKE build config debug
@cmake --build .  --config debug >> %logfile% 2>&1

@ECHO   Running CMAKE build config release
@cmake --build .  --config release >> %logfile% 2>&1

@ECHO   Running CMAKE build target release
@cmake --build .  --target install --config release >> %logfile% 2>&1

@ECHO   Running CMAKE build target debug
@cmake --build .  --target install --config debug >> %logfile% 2>&1

@popd

@ECHO.
@ECHO Updating environment variables
@SET OpenCV_DIR=!rootdir!
@SET OPENCV_INCDIR=!rootdir!\include
@SET OPENCV_BINDIR=!rootdir!\x64\%VISUAL_STUDIO_VC%\bin
@SET OPENCV_LIBDIR=!rootdir!\x64\%VISUAL_STUDIO_VC%\lib

REG ADD "HKEY_CURRENT_USER\Environment" /v OpenCV_DIR /t REG_SZ /f /d "%OpenCV_DIR%" >> %logfile% 2>&1

REG ADD "HKEY_CURRENT_USER\Environment" /v OPENCV_INCDIR /t REG_SZ /f /d "%OPENCV_INCDIR%" >> %logfile% 2>&1

REG ADD "HKEY_CURRENT_USER\Environment" /v OPENCV_BINDIR /t REG_SZ /f /d "%OPENCV_BINDIR%" >> %logfile% 2>&1

REG ADD "HKEY_CURRENT_USER\Environment" /v OPENCV_LIBDIR /t REG_SZ /f /d "%OPENCV_LIBDIR%" >> %logfile% 2>&1


@pushd %rootdir%\x64\%VISUAL_STUDIO_VC%\lib
@set OPENCV_LIBRARIES=
@for /f "delims=" %%f in ('dir /b /a-d ^| findstr /i "[0-9][^d]\.lib"') do @set OPENCV_LIBRARIES=!OPENCV_LIBRARIES!%%f;
@popd

@pushd %rootdir%\x64\%VISUAL_STUDIO_VC%\lib
@set OPENCV_LIBRARIES_DEBUG=
@for /f "delims=" %%f in ('dir /b /a-d ^| findstr /i "[0-9]d\.lib"') do @set OPENCV_LIBRARIES_DEBUG=!OPENCV_LIBRARIES_DEBUG!%%f;
@popd

REG ADD "HKEY_CURRENT_USER\Environment" /v OPENCV_LIBRARIES /t REG_SZ /f /d "%OPENCV_LIBRARIES%"

REG ADD "HKEY_CURRENT_USER\Environment" /v OPENCV_LIBRARIES_DEBUG /t REG_SZ /f /d "%OPENCV_LIBRARIES_DEBUG%"

@ECHO @SET OpenCV_DIR=%OpenCV_DIR% > %rootdir%\opencv_environment.bat
@ECHO @SET OPENCV_INCDIR=%OPENCV_INCDIR% > %rootdir%\opencv_environment.bat
@ECHO @SET OPENCV_BINDIR=%OPENCV_BINDIR% >> %rootdir%\opencv_environment.bat
@ECHO @SET OPENCV_LIBDIR=%OPENCV_LIBDIR% >> %rootdir%\opencv_environment.bat

@ECHO @SET OPENCV_LIBRARIES=%OPENCV_LIBRARIES% >> %rootdir%\opencv_environment.bat
@ECHO @SET OPENCV_LIBRARIES_DEBUG=%OPENCV_LIBRARIES_DEBUG% >> %rootdir%\opencv_environment.bat

@ECHO.
@ECHO Cleaning temporary files
@IF EXIST %local_repository% (
  @rd /s /q %local_repository% >> %logfile% 2>&1
)

@IF EXIST %builddir% (
  @rd /s /q %builddir% >> %logfile% 2>&1
)

@IF EXIST %instaldir% (
  @rd /s /q %instaldir% >> %logfile% 2>&1
)

@IF EXIST tmp (
  @rd /s /q tmp >> %logfile% 2>&1
)

@move build.log %rootdir%\build.log

@ECHO.
@ECHO Install complete, please restart any program that use Boost before compiling/building.

@ENDLOCAL