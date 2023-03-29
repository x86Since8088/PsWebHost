Function Get_Profile {
    param([int64]$AccountNumber)
    $WebUserProfileFile = "$Global:ScriptFolder\WebUserProfiles\$AccountNumber.cli.xml"
    if (Test-Path $WebUserProfileFile)
    {
        $Record = Import-Clixml $WebUserProfileFile
        $Record.LogonHistory = ([psobject[]](Get_LogonInformation)) + $Record.LogonHistory | select -First 20
    }
    ELSE
    {
        New-Object psobject -Property @{
            'Screen Name'=([string]$null)
            'Account Name'=([string]$null)
            'First Name'=([string]$null)
            'Last Name'=([string]$null)
            'Account Number'=([int64]$AccountNumber)
            Email=([string[]]$null)
            Skype=([string[]]$null)
            'Google+'=([string[]]$null)
            LinkedIn=([string[]]$null)
            Facebook=([string[]]$null)
            'Home Page'=([string[]]$null)
            'Password Hash'=([string]$null)
            'Linked Accounts'=([int64[]]$null)
            'Email Confirmation'=([string]$Null)
            'Locked Out'=($False)
            Enabled=($True)
            Introduction=([string]$Null)
            Customers=([string]$Null)
            Children=([string]$Null)
            LogonHistory=([psobject[]](Get_LogonInformation))
        }
    }
}
