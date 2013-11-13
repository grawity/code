:: Locate and start the latest version of Microsoft .NET C# Compiler
@setlocal
@set framework=Framework64
@if "%PROCESSOR_ARCHITECTURE%"=="x86" set framework=Framework
@for /d %%d in ("%SystemRoot%\Microsoft.NET\%framework%\v*.*") do @(
	set version=%%~nxd
	set dir=%%~d
)
@echo Using .NET %framework% %version%
@set PATH=%dir%;%PATH%
@%*
