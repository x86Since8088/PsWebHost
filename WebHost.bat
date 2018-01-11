SETLOCAL
SET PowerShellScript="%~dpn0.ps1"
@ECHO Script: %PowerShellScript% 
ECHO Arguments: %*
:Launch
Powershell -NoProfile -nologo -ExecutionPolicy bypass -noninteractive -file %PowerShellScript% -noie
timeout 60
Goto Launch
ENDLOCAL