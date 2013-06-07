@echo off & setlocal

set havecomm
call :havecomm notepad
set havecomm
call :havecomm notepad.exe
set havecomm
call :havecomm foobiex
set havecomm
goto :eof


    :havecomm
      set havecomm=
      if not "%~$PATH:1"=="" (
        set "havecomm=%~$PATH:1"
      ) else (
        for %%e in (%PATHEXT%) do (
          for %%i in (%1%%e) do (
            if not "%%~$PATH:i"=="" (
              set "havecomm=%%~$PATH:i"
              goto :eof
            )
          )
        )
      )
      goto :eof