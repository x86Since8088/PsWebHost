$Scriptfolder = Split-Path $MyInvocation.MyCommand.Definition
$Main
$Threads = 3
do 
{
    $Processes = Get-WmiObject -Class win32_process -Property * -Filter "commandline like '%powershell.exe%-noninteractive%$($Scriptfolder -replace '\\','\\')\\WebHost.ps1%-NoIE%'"
    [int]$LaunchCount = $Threads - $Processes.count
    if ($LaunchCount -gt 0)
    {
        (1..($LaunchCount)) | %{$I=$_;start -WindowStyle Minimized powershell -ArgumentList  "-executionpolicy bypass -noprofile -nologo -noninteractive -command ""& '$Scriptfolder\WebHost.ps1' -NoIE > '$Scriptfolder\Webhost_$I.log'"""}
    }
    sleep 5
}
until ($False)