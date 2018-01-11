SETLOCAL
SET PowerShellScript="%~dpn0.ps1"
@ECHO Script: %PowerShellScript% 
ECHO Arguments: %*
Powershell -NoProfile -noexit -nologo -ExecutionPolicy bypass -noninteractive -file %PowerShellScript% 
ENDLOCAL