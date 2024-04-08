@setlocal & prompt $g
@if not "%~1"=="" goto :%~1 || goto :eof

:monoff
	call dotnet csc /t:winexe /o /r:System.dll /r:System.Windows.Forms.dll /out:"%SystemRoot%\monoff.scr" monoff.cs
	goto :eof
