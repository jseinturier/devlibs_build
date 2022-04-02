@echo on
@cls
@SETLOCAL EnableDelayedExpansion

@rem Clone and build Boost C++ library from official Git repository.
@rem This installation script needs that Git binaries are presents within PATH
@rem Git for windows can be downloaded from https://gitforwindows.org/

@ECHO Booost build

@rem check if Git is available
@WHERE git >nul 2>nul
@IF NOT %ERRORLEVEL% EQU 0 (
  @ECHO Git command not found, please install Git for windows from https://gitforwindows.org
  @EXIT /B
)

@SET logfile=%~dp0%build.log

@SET gittag=boost-1.78.0

@SET rootdir=%~dp0!gittag!

@SET tmpdir=%~dp0tmp

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

@ECHO.
@ECHO Getting Boost from git repository to %gitdir%
@IF EXIST %gitdir% (
    @ECHO Updating Boost local repository
    @pushd %gitdir%
    rem git pull --recurse-submodules --rebase "https://github.com/boostorg/boost.git" %gittag%
    rem git pull --autostash  --recurse-submodules --rebase "https://github.com/boostorg/boost.git" %gittag%
    @popd
) ELSE (
    @ECHO Clonning Boost
    
    @mkdir %gitdir%
    @pushd %gitdir%
    @git clone -b %gittag% --depth 1 --recurse-submodules --single-branch "https://github.com/boostorg/boost.git" >> %logfile% 2>&1
    
    @IF %ERRORLEVEL% EQU 0 (
      @ECHO Cloning done
    ) ELSE (
      @ECHO Error during Git clone, aborting.
      @EXIT /B
    )
    @popd
)

@ECHO.
@ECHO Building Boost

@IF EXIST %installdir% (
  @rd /s /q %installdir%
)
@md %installdir%
@mkdir %installdir%\%gittag%

@pushd %gitdir%\boost
@call bootstrap.bat >> %logfile% 2>&1
.\b2 install --prefix=%installdir%\%gittag% --exec-prefix=%installdir%\%gittag% link=shared address-model=64 threading=multi --build-type=complete debug-symbols=on debug-store=database >> %logfile% 2>&1
@popd
@mkdir %installdir%\%gittag%\include_nover
@for /f %%f in ('dir /ad /b %installdir%\%gittag%\include\') do xcopy /e /s %installdir%\%gittag%\include\%%f\* %installdir%\%gittag%\include_nover >> %logfile% 2>&1

@ECHO.
@ECHO Installing to %rootdir%
@xcopy /e /h /i %installdir%\%gittag%\include %rootdir%\include >> %logfile% 2>&1
@xcopy /e /h /i %installdir%\%gittag%\lib %rootdir%\lib >> %logfile% 2>&1
@mkdir %rootdir%\include_nover
@for /f %%f in ('dir /ad /b %installdir%\%gittag%\include\') do xcopy /e /s %installdir%\%gittag%\include\%%f\* %rootdir%\include_nover >> %logfile% 2>&1

@ECHO.
@ECHO Updating environment variables
@SET BOOST_ROOT=!rootdir!
@SET BOOST_INCLUDEDIR=!BOOST_ROOT!\include_nover
@SET BOOST_LIBRARYDIR=!BOOST_ROOT!\lib

@REG ADD "HKEY_CURRENT_USER\Environment" /v BOOST_ROOT /t REG_SZ /f /d "%BOOST_ROOT%" >> %logfile% 2>&1

@REG ADD "HKEY_CURRENT_USER\Environment" /v BOOST_INCLUDEDIR /t REG_SZ /f /d "%BOOST_INCLUDEDIR%" >> %logfile% 2>&1

@REG ADD "HKEY_CURRENT_USER\Environment" /v BOOST_LIBRARYDIR /t REG_SZ /f /d "%BOOST_LIBRARYDIR%" >> %logfile% 2>&1

@ECHO @SET BOOST_ROOT=%BOOST_ROOT% > %rootdir%\boost_environment.bat
@ECHO @SET BOOST_INCLUDEDIR=%BOOST_INCLUDEDIR% >> %rootdir%\boost_environment.bat
@ECHO @SET BOOST_LIBRARYDIR=%BOOST_LIBRARYDIR% >> %rootdir%\boost_environment.bat

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
@ECHO Install complete, please restart any program that use Boost before compiling/building.

@ENDLOCAL