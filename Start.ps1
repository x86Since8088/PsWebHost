param (
    [switch]$Loadenvironment
)
[string]$Global:Project_Root=split-path $MyInvocation.MyCommand.Definition
[string]$Global:Project_Data=$Global:Project_Root + '_Data'
if (-not (test-path $Global:Project_Data)) {mkdir $Global:Project_Data}
Set-Location $Global:Project_Root
[string]$Global:Project_Temp  = $Global:Project_Data + '\temp'
                                if (-not (test-path $Global:Project_Temp)) {mkdir $Global:Project_Temp}
[string]$Global:Project_Apps  = $Global:Project_Root + '\Apps'
                                if (-not (test-path $Global:Project_Apps)) {mkdir $Global:Project_Apps}
[string]$Global:Project_Modules=$Global:Project_Root + '\Modules'
                                if (-not (test-path $Global:Project_Modules)) {mkdir $Global:Project_Modules}
[string]$Global:Project_Storage=$Global:Project_Data + '\Storage'
                                if (-not (test-path $Global:Project_Storage)) {mkdir $Global:Project_Storage}
[string]$Global:Project_URLRoot = '/'
                                if (-not (test-path $Global:Project_Temp)) {mkdir $Global:Project_Temp}

. "$Global:Project_Root\Config\Config.ps1"
Set-Location $Global:Project_Root

Write-Verbose -Verbose -Message "Modifying $env:PSModulePath to give preference to '$Global:Project_Modules'."
$env:PSModulePath="$Global:Project_Modules;"+($env:PSModulePath.Replace("$Global:Project_Modules;",''))

Function ReLoadFunctions_Start {
    Remove-Module PSWEB*,*WebHost*,*_WS -ErrorAction Ignore 2> $null
    Get-ChildItem $global:Project_Root\Modules\*.psm1 -recurse|
        Where-Object{
            ($_.BaseName -eq $_.Directory.Basename) -or 
            ($_.BaseName -eq $_.Director.Parent.Basename)
        } |
        ForEach-Object{
            Import-Module $_.fullname -DisableNameChecking
        }
}
. ReLoadFunctions_Start

. "$Global:Project_Root\Listener\Listen.ps1" -Loadenvironment:$Loadenvironment

lastcall
return

Get-ChildItem "$global:Project_Root\Listener" |Where-Object{$_} | ForEach-Object {
    $ListenerFile = $_
    #$JobName = 'WebHostListener_' + $File.BaseName
    #$ExistingJob = Get-Job -Name $JobName -ErrorAction SilentlyContinue
    #if ($null -eq $ExistingJob.PSEndTime) {
        
    #} else {
    #    Start-Job -Name $JobName -ScriptBlock {
    #        $ListenerFile=$Using:ListenerFile
    #        $global:Project_Root=$Using:global:Project_Root
            . $ListenerFile.FullName
    #    }
    #}
}