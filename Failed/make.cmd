@set path=bin;%path%

call csc ^
/out:backup.exe ^
/r:System.dll ^
/r:System.Core.dll ^
backup.cs

goto :EOF

call csc ^
/out:youtube.exe ^
/r:System.dll ^
/r:System.Drawing.dll ^
/r:System.Windows.Forms.dll ^
youtube.cs

