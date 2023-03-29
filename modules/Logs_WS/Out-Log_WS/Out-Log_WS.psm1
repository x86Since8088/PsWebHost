Function Out-Log_WS {
    param (
        [string]$Message,
        [pscustomobject]$Data,
        [switch]$Verbose,
        [string]$ComputerName = $Env:ComputerName
    )
    $Date=(get-date)
    try {
        $DataJSON = ($Data|ConvertTo-Json -Compress)
    }
    catch {
        #Some things cannot be serialized like [System.Collections.ListDictionaryInternal].  Grab the text and keep the final output in JSON.
        $DataJSON = ("##JSON serialization failed.  Converting to text first.##`n"+($Data|format-list|out-string)|ConvertTo-Json -Compress)
    }
    [System.Collections.ListDictionaryInternal]
    $Data = [pscustomobject]@{
        ComputerName=$env:COMPUTERNAME
        Date=get-date
        Message=$Message
        Data=$DataJSON
    }| Select Date,ComputerName,Message,@{Name='Data';Expression={$_.data | ConvertTo-Json}} 
    if ($Verbose) {write-verbose -Verbose -message (($Data | format-list | out-string) -replace '\s*(\n)','$1') -replace '(\n)\n*','$1'}
    $Data | export-csv -Append -Path $Global:LogFile -Delimiter "`t" -NoTypeInformation
}
New-Alias log -Value Out-Log_WS -Force -ErrorAction Continue