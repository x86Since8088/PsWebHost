[cmdletbinding()]
param (

)
begin{
    Write-Verbose -Message 'Initializing variables.' -Verbose
    $ScriptFolder             = Split-Path $MyInvocation.MyCommand.Definition
    $ScriptName               = Split-Path -Leaf $MyInvocation.MyCommand.Definition
    $ScriptPath               = $MyInvocation.MyCommand.Definition

    Write-Verbose -Message 'Launching _init_.ps1'
        $Error.Clear()
        . "$ScriptFolder\_init.ps1"
        $InitErrors = $Error.Clone()
    Write-Verbose -Message 'Launching _init_.ps1 - complete.  Validating...'
    Get-Content -Path "$ScriptFolder\Requiredmodules.json" |
        ConvertFrom-Json -AsHashtable|
        ForEach-Object{
            $ModuleRequirement = $_
            if ($null -eq $ModuleRequirement.Version) {$ModuleRequirement.Version = '*'}
            [array]$matches = $Global:PSWebServer.modules.psm1|Where-Object{$ModuleRequirement.Name -eq $_.baseName}
            [array]$matches = $Matches | 
                Where-Object{
                    Write-Verbose -Message "Module found: $($_.Name)"
                    Import-Module -Name $_.FullName -DisableNameChecking -Force
                    Get-Module -Name $_.basename | Where-Object { $_.Version -like $ModuleRequirement.Version }
                }
            if($matches.count -lt 1){
                Write-Error -Message "Module not found: $($_.Name)"
            }
        }
    Write-Verbose -Message 'Launching _init_.ps1 - complete.  Validating... - complete.'

    Write-Verbose -Message 'Validating SQLite validation.'
        $PSWebServer.SQLite                   = [hashtable]::Synchronized(@{})
        $PSWebServer.SQLite.Path              = "$($PSWebServer.Project_Data.Path)\SQLite"
                                                if (-not (test-path $PSWebServer.SQLite.Path)) {mkdir $PSWebServer.SQLite.Path}
        $PSWebServer.SQLite.Databases         = [hashtable]::Synchronized(@{})
        $PSWebServer.SQLite.Databases.dbs     = gci "$($PSWebServer.SQLite.Path)" -Filter *.db -Recurse
                                                "$($PSWebServer.SQLite.Path)\Events.db",
                                                    "$($PSWebServer.SQLite.Path)\Metrics.db",
                                                    "$($PSWebServer.SQLite.Path)\Sessions.db",
                                                    "$($PSWebServer.SQLite.Path)\Users.db",
                                                    "$($PSWebServer.SQLite.Path)\Systems.db",
                                                    "$($PSWebServer.SQLite.Path)\Settings.db",
                                                    "$($PSWebServer.SQLite.Path)\Secrets.db"|
                                                        ForEach-Object{
                                                            if (-not $PSWebServer.SQLite.Databases.dbs.Contains($_)) {
                                                                $PSWebServer.SQLite.Databases.dbs += $_
                                                            }
                                                        }

        $PSWebServer.SQLite.Databases.path|  
            ForEach-Object{
                $DBPath = $_
                $PSWebServer.SQLite.Databases
            }

    #Install-Module -Name PSSQLite -Force
}
