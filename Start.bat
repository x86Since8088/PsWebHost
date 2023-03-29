SETLOCAL
SET PowerShellScript="%~dpn0.ps1"
@ECHO Script: %PowerShellScript% 
ECHO Arguments: %*
:Launch
Powershell -NoProfile -nologo -ExecutionPolicy bypass -noninteractive -file %PowerShellScript%
timeout 60 > Null
Goto Launch
ENDLOCAL