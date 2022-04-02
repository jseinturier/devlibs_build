@echo on
@cls
@SETLOCAL EnableDelayedExpansion

@rem Clone and build Eigen C++ library from official Git repository.
@rem 
@rem This installation script needs that Git binaries are presents within PATH
@rem Git for windows can be downloaded from https://gitforwindows.org
@rem 
@rem CMake for windows is also needed and its binaries have to be pointed by PATH variable.
@rem CMake for windows can be downloaded from https://cmake.org

@ECHO Eigen build

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

@SET logfile=%~dp0%build.log

@SET gittag=3.4.0

@SET rootdir=%~dp0!gittag!

@SET tmpdir=%~dp0\tmp

@SET gitdir=!tmpdir!\git
@SET builddir=!tmpdir!\build
@SET installdir=!tmpdir!\install

@IF EXIST %rootdir% (
  @rd /s /q %rootdir%
) 
@md %rootdir%

@IF EXIST %tmpdir% (
  @rd /s /q %tmpdir%
)
@md %tmpdir%

@ECHO   Using repository %gitdir%
@ECHO   Installing into %rootdir%

@SET VISUAL_STUDIO_VC=vc17
@SET CMAKE_GENERATOR="Visual Studio 17 2022"
@SET CMAKE_GENERATOR_TOOLSET="v143,host=x64"

@ECHO.
@ECHO Getting Eigen from git repository
@IF EXIST %gitdir% (
  @ECHO   Updating Eigen
) ELSE (
  @ECHO   Clonning Eigen
  @mkdir %gitdir%
  @pushd %gitdir%
  @git clone -b %gittag% --depth 1 --single-branch "https://gitlab.com/libeigen/eigen.git" >> %logfile% 2>&1
  @popd
)

@IF EXIST %builddir% (
  @rmdir %builddir%
)
@mkdir %builddir%
@mkdir %builddir%\eigen
    
@IF EXIST %installdir% (
  @rmdir %installdir%
)
@mkdir %installdir%
@mkdir %installdir%\eigen

@ECHO.
@ECHO CMAKE processing

@pushd %builddir%\eigen

@ECHO   Running CMAKE (see %logfile% for details)
@SET CMAKE_OPTIONS=

@ECHO   CMake options:
@ECHO     General: %CMAKE_OPTIONS%

@cmake -G%CMAKE_GENERATOR% -T%CMAKE_GENERATOR_TOOLSET% %CMAKE_OPTIONS% -DCMAKE_INSTALL_PREFIX=%installdir%\eigen %gitdir%\eigen > %logfile% 2>&1

@ECHO   Running CMAKE build config debug (see %logfile% for details)
@cmake --build .  --config debug >> %logfile% 2>&1

@ECHO   Running CMAKE build config release (see %logfile% for details)
@cmake --build .  --config release >> %logfile% 2>&1

@ECHO   Running CMAKE build target release (see %logfile% for details)
@cmake --build .  --target install --config release >> %logfile% 2>&1

@ECHO   Running CMAKE build target debug (see %logfile% for details)
@cmake --build .  --target install --config debug >> %logfile% 2>&1

@popd

@ECHO.
@ECHO Installing to %rootdir%
@xcopy /e /h /i %installdir%\eigen\include %rootdir%\include >> %logfile% 2>&1
@xcopy /e /h /i %installdir%\eigen\share %rootdir%\share >> %logfile% 2>&1

@ECHO.
@ECHO Updating environment variables
@SET Eigen3_DIR=%rootdir%\share\eigen3\cmake
@SET EIGEN3_INCLUDE_DIR=%rootdir%\include\eigen3

@REG ADD "HKEY_CURRENT_USER\Environment" /v Eigen3_DIR /t REG_SZ /f /d "%Eigen3_DIR%" >> %logfile% 2>&1
@REG ADD "HKEY_CURRENT_USER\Environment" /v EIGEN3_INCLUDE_DIR /t REG_SZ /f /d "%EIGEN3_INCLUDE_DIR%" >> %logfile% 2>&1

@ECHO @SET Eigen3_DIR=%Eigen3_DIR% > %rootdir%\eigen_environment.bat
@ECHO @SET EIGEN3_INCLUDE_DIR=%EIGEN3_INCLUDE_DIR% >> %rootdir%\eigen_environment.bat

@ECHO.
@ECHO Cleaning temporary files
@IF EXIST %gitdir% (
  @rd /s /q %gitdir%
)

@IF EXIST %builddir% (
  @rd /s /q %builddir%
)

@IF EXIST %installdir% (
  @rd /s /q %installdir%
)

@IF EXIST %tmpdir% (
  @rd /s /q %tmpdir%
)

@move build.log %rootdir%\build.log

@ECHO.
@ECHO Install complete, please restart any program that use Eigen before compiling/building.

@ENDLOCAL