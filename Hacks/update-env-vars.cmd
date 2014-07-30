@echo off
:main
	set __append_path=n
	for /f "usebackq tokens=1,2,* delims=	" %%a in (`reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment"`) do call :process "%%~a" "%%~b" "%%~c"
	set __append_path=y
	for /f "usebackq tokens=1,2,* delims=	" %%a in (`reg query HKCU\Environment`) do call :process "%%~a" "%%~b" "%%~c"
	set __append_path=
	goto :eof

:process
	set "__var_name=%~1"
	if not "%__var_name:~0,4%"=="    " goto :eof
	set "__var_name=%__var_name:~4%"
	:: It is not necessary to skip %PROMPT% -- I just want
	:: to avoid certain kinds of confusion that may result.
	if /i "%__var_name%"=="PROMPT" goto :process_next
	if /i "%__var_name%"=="PATH" (
		if "%__append_path%"=="y" (
			set "%__var_name%=%PATH%;%~3"
			goto :process_next
		)
	)
	set "%__var_name%=%~3"

:process_next
	set __var_name=
	goto :eof
