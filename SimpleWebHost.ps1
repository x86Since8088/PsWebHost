<#
.Synopsis
Simple Web Service
.Description
Contact Edward Skarke if you have any issues.  
Infosec will get alarms from time to time due to the nature if this automation.
#>
param (
    [switch]$LoadVariables,
    [switch]$RunInProcess
)

. "$psscriptroot\_init.ps1"

#Refine this.
$ExistingPID = (netsh http show servicestate requestq) -join "`n" -split 'Process IDs:\s*\n\s*' -like "*$($url[0])*" -split '\s|\n' | Where-Object { $_ } | Select-Object -First 1

####################################################################################################################################################################################
####################################################################################################################################################################################
# Start the job that will isolate the HTTPListerer to a new and unique PID that will be terminated with the job and not corrupt the current environment.
####################################################################################################################################################################################
####################################################################################################################################################################################
$HTTPListenerScriptBlock = {
    [string]$ScriptPath = $Using:ScriptPath
    [string]$ScriptName = $Using:ScriptName
    [string]$Project_Root = $Using:Project_Root
    [string]$($Global:PSWebServer.Project_Root.Path) = $Project_Root
    [string]$DataPath = $Using:DataPath
    [datetime]$Start = $Using:Start
    [string]$Global:LogFile = $Using:LogFile
    [string[]]$FirstHttpURL = $using:FirstHttpURL

    ###################################
    # Load PS modules for project
    ###################################
    Function reloadmodules {
        Get-ChildItem $Project_Root\modules | Get-ChildItem -Filter *.psm1 | ForEach-Object {
            try { remove-module -ErrorAction SilentlyContinue $_.basename } catch {}
            import-module $_.Fullname -DisableNameChecking -Force
        }
    }
    . reloadmodules

    $FQDN = $Using:FQDN
    $URL = $Using:URL

    function reload {
        #############################################
        # Set initial default variables.
        # - Some items have been nested in routes.ps1
        #############################################

        # request actions.
        $RoutesFile = "$Project_Root\routes.ps1"
        if (-not (test-path $RoutesFile)) {
            Set-Content -Encoding UTF8 -Path $RoutesFile -Value {
                #############################################
                # Set initial default variables.
                # - New route folders will have default documents populated.
                #############################################




                #############################################
                # Create and return a hashtable of routes.
                # 
                #############################################
                # This file should only contain one hashtable of routes.
                $HT = @{
                    'GET /blank' = { return '' }
                    #'GET /'  = { . "$($Global:PSWebServer.Project_Root.Path)\routes\Route_GET.ps1" }
                    #'POST /' = { ([scriptblock]::Create(". '$($Global:PSWebServer.Project_Root.Path)\routes\Route_POST.ps1'")) }
                }

                #Look for route files that will provide the response to each possible method.
                Get-ChildItem -Path "$($Global:PSWebServer.Project_Root.Path)\routes" -Recurse -Filter Route_*.ps1 |
                Where-Object { $_.Name -like 'Route_*.ps1' } | # Make sure only the right files are returned 
                ForEach-Object {
                    $File = $_
                    $Method = $File.BaseName.Replace('Route_', '')
                    $RoutePath = '/' + $File.DirectoryName.Replace("$($Global:PSWebServer.Project_Root.Path)\routes\", '').Replace('\', '/')
                    $HT.Add("$Method $RoutePath", ([scriptblock]::Create(". $($File.FullName)")))
                }
                $HT    
            }.ToString()
        }
        $routes = & $RoutesFile
    }

    #Load initial variables.
    . reload

    $listener = new-object system.net.httplistener
    $url | Where-Object { $_ } | ForEach-Object { $listener.prefixes.add($_) }
    $listener.AuthenticationSchemes = [System.Net.AuthenticationSchemes]::Anonymous
    #$listener.AuthenticationSchemeSelectorDelegate
    $listener.start()


    start-job -Name "PeriodicRequest_$FirstHttpURL" -ScriptBlock {
        [string[]]$FirstHttpURL = $using:FirstHttpURL
        $Blank = ($FirstHttpURL -replace '//*$') + '/blank'
        Invoke-WebRequest -UseBasicParsing -Uri $Blank -TimeoutSec 1 > $null
        Start-Sleep 10
    }

    [pscustomobject]@{
        Listerner = $listener | Select-Object *
        Routes    = $routes
        Form      = $form
    } | Select-Object * 

    while ($listener.islistening) {
        $context = $listener.getcontext()
        $global:context = $Context
        $request = $context.request
        $global:request = $request
        $response = $context.response
        $global:response = $response

        $pattern = "{0} {1}" -f $request.httpmethod, $request.url.localpath

        "$(get-date) $pattern"
        $route = $routes.get_item($pattern)

        if ($pattern -eq 'GET /abort') { $listener.Stop() }
        elseif ($route -eq $null) {
            $response.statuscode = 404
            Out-Log_WS -Message "Not found: $pattern" `
                -Data ([pscustomobject]@{
                    Route   = $Route
                    Pattern = $pattern
                })
        }
        else {
            $route
            [string]$content = & $route
            Out-Log_WS -Message "New request: $pattern" `
                -Data ([pscustomobject]@{
                    Route   = $Route
                    Pattern = $pattern
                    Content = $content
                })

            $buffer = [system.text.encoding]::utf8.getbytes($content)
            $response.contentlength64 = $buffer.length
            $response.outputstream.write($buffer, 0, $buffer.length)
        }

        if ($pattern -eq 'GET /abort') {
            $response.close();
            $listener.stop();
            $listener.Prefixes.Clear()
            $listener.Close()
        }
        . reload
    }

    $listener.Stop()
    $listener.Prefixes.Clear()
    $listener.Close()
    $listener.Dispose()
}

if ($LoadVariables) { return (Write-Verbose -Verbose -Message "-LoadVariables was specified, so the script is ending after creating initial variables.") }

stop-job -Name $ScriptName -ErrorAction SilentlyContinue
if ($RunInProcess) {
    . $HTTPListenerScriptBlock | ForEach-Object { $_; write-warning "Remember to navigate to $($url[0])/abort to stop this script propperly!!!!" }
}
ELSE {
    start-job -Name $ScriptName -ScriptBlock $HTTPListenerScriptBlock
    Watch-Job_DOES
}