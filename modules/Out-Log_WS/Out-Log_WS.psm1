Function Out-Log_WS {
    param (
        [string]$ComputerName = $Env:ComputerName,
        [datetime]$Date=(get-date),
        [string[]]$Message,
        [pscustomobject]$Data
    )
    [pscustomobject]@{
        ComputerName=$env:COMPUTERNAME
        Date=get-date
        Message='Not yet valid'
        Data=($Data|ConvertTo-Json -Compress)
    }| Select | export-csv -Append -Path $Global:LogFile -Delimiter "`t" -NoTypeInformation
}
New-Alias log -Value Out-Log_WS -Force -ErrorAction Continue