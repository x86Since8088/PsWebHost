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

###################################
# Variable initialization
###################################
#  Load variables before starting job so they can also be used for debugging.
#  . .\SimpleWebHost.ps1 -LoadVariables - will load and variables and exit with a friendly message.
[string]$ScriptPath = $MyInvocation.MyCommand.Definition | ?{Test-Path $_}
[string]$ScriptName = Split-Path -Leaf $ScriptPath
[string]$DataPath=split-path $ScriptPath
[string]$Global:Project_Root=$DataPath
[string]$Project_Root = $Global:Project_Root
[datetime]$Start = Get-Date
[string]$LogFile = "$DataPath\logs\$ScriptName`_$($Start.ToString('yyyMMdd')).log"
if ($ScriptPath -eq '') {return 'scriptpath not resolved'}
if (-not (test-path $Project_Root))         {mkdir $Project_Root}
if (-not (test-path $Project_Root\error))    {mkdir $Project_Root\error}
if (-not (test-path $Project_Root\logs))    {mkdir $Project_Root\logs}
if (-not (test-path $Project_Root\modules)) {mkdir $Project_Root\modules}
cd $Project_Root

###################################
# Load PS modules for project
###################################
gci $Project_Root\modules|gci -Filter *.psm1 | ForEach-Object{
    try {remove-module -ErrorAction SilentlyContinue $_.basename} catch {}
    import-module $_.Fullname -DisableNameChecking -Force
}

###################################
# Declare URLs that will be used.
###################################
. "$Project_Root\Bindings.ps1"



#Refine this.
$ExistingPID=(netsh http show servicestate requestq) -join "`n" -split 'Process IDs:\s*\n\s*' -like "*$($url[0])*" -split '\s|\n' | ?{$_} | select -First 1

####################################################################################################################################################################################
####################################################################################################################################################################################
# Start the job that will isolate the HTTPListerer to a new and unique PID that will be terminated with the job and not corrupt the current environment.
####################################################################################################################################################################################
####################################################################################################################################################################################
$HTTPListenerScriptBlock = {
[string]$ScriptPath=$Using:ScriptPath
[string]$ScriptName=$Using:ScriptName
[string]$Project_Root=$Using:Project_Root
[string]$Global:Project_Root=$Project_Root
[string]$DataPath=$Using:DataPath
[datetime]$Start=$Using:Start
[string]$Global:LogFile=$Using:LogFile
[string[]]$FirstHttpURL = $using:FirstHttpURL

###################################
# Load PS modules for project
###################################
Function reloadmodules {
    gci $Project_Root\modules|gci -Filter *.psm1 | ForEach-Object{
        try {remove-module -ErrorAction SilentlyContinue $_.basename} catch {}
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
$RoutesFile="$Project_Root\routes.ps1"
if (-not (test-path $RoutesFile)) {
    Set-Content -Encoding UTF8 -Path $RoutesFile -Value {
#############################################
# Set initial default variables.
# - New route folders will have default documents populated.
#############################################

Function ReplaceMissingContentItems {
    param (
        [string]$Path,
        [string]$GlobalVariableName,
        [scriptblock]$ScriptBlock = {},
        [string]$Text,
        [string]$Encoding = 'UTF8'
    )
    $SBText=$ScriptBlock.ToString()
    if ($SBText -ne '') {$Text = $SBText}
    split-path $Path | 
        Where-Object{-not (test-path $_)} |
        ForEach-Object{mkdir $_}
    if (-not (test-path $Path)) {
        $Text | Out-File -Encoding $Encoding -FilePath $Path 
    }
    if ($GlobalVariableName -ne '') {
        New-Variable -Force -Scope global -Name $GlobalVariableName -Value ((Get-Content $Path) -join "`n")
    }
}

if (-not (test-path $Global:Project_Root\routes)) {mkdir $Global:Project_Root\routes}
# Lets externalize the HTML sources so that thet can be updated while the server is running.
    ReplaceMissingContentItems -Path "$Global:Project_Root\routes\Template.html" `
        -GlobalVariableName TemplateFile `
        -Text @'
            <!DOCTYPE HTML>
            <html>
            <head>
            <title>Example Web App</title>
            <style type="text/css">
            html, body, #container {height:95%}
            body {font-family:verdana;line-height:1.5}
            form, #container, p {align-items:center;display:flex;flex-direction:column;justify-content:center}
            input {border:1px solid #999;border-radius:4px;margin-bottom:10px;padding:4px}
            input[type=submit] {padding:6px 10px}
            label, p {font-size:10px;padding-bottom:2px;text-transform:uppercase}
            </style>
            </head>
            <body>
            <div id="container">
            <div id="content">
            {page}
            </div>
            </div>
            </body>
            </html>
'@


    ReplaceMissingContentItems -Path "$Global:Project_Root\routes\Form.html" `
        -GlobalVariableName FormFile `
        -Text @'
<form method="post">
<label for="person">Name</label>
<input type="text" name="person" value="" required />
<input type="submit" name="submit" value="Submit" />
</form>
'@


    ReplaceMissingContentItems -Path "$Global:Project_Root\routes\FormResponse.html" `
        -GlobalVariableName FormResponseFile `
        -Text @'
    <p>Hello {name}.<br/><a href="/">Say hello again?</a></p>
'@

#Default /Route_GET.ps1
    ReplaceMissingContentItems -Path "$Global:Project_Root\routes\Route_GET.ps1" `
        -GlobalVariableName '' `
        -ScriptBlock { return (render $template $form) }

#Default /Route_post.ps1
    ReplaceMissingContentItems -Path "$Global:Project_Root\routes\Route_POST.ps1" `
        -GlobalVariableName '' `
        -ScriptBlock {
            # get post data.
            $data = extract $request

            # get the submitted name.
            $name = $data.item('person')

            # render the 'FormResponse' snippet, passing the name.
            $page = render $FormResponse @{name = $name}

            # embed the snippet into the template.
            return (render $template $page)
        }



#############################################
# Create and return a hashtable of routes.
# 
#############################################
        # This file should only contain one hashtable of routes.
        $HT = @{
          'GET /blank' = { return '' }
          #'GET /'  = { . "$Global:Project_Root\routes\Route_GET.ps1" }
          #'POST /' = { ([scriptblock]::Create(". '$Global:Project_Root\routes\Route_POST.ps1'")) }
        }

        #Look for route files that will provide the response to each possible method.
        Get-ChildItem -Path "$Global:Project_Root\routes" -Recurse -Filter Route_*.ps1 |
         Where-Object{$_.Name -like 'Route_*.ps1'} | # Make sure only the right files are returned 
         ForEach-Object {
            $File = $_
            $Method = $File.BaseName.Replace('Route_','')
            $RoutePath = '/' + $File.DirectoryName.Replace("$Global:Project_Root\routes\",'').Replace('\','/')
            $HT.Add("$Method $RoutePath",([scriptblock]::Create(". $($File.FullName)")))
        }
        $HT    
    }.ToString()
}
$routes = . $RoutesFile
}

#Load initial variables.
. reload

$listener = new-object system.net.httplistener
$url|?{$_}|%{$listener.prefixes.add($_)}
$listener.AuthenticationSchemes = [System.Net.AuthenticationSchemes]::Anonymous
#$listener.AuthenticationSchemeSelectorDelegate
$listener.start()


start-job -Name "PeriodicRequest_$FirstHttpURL" -ScriptBlock {
    [string[]]$FirstHttpURL = $using:FirstHttpURL
    $Blank=($FirstHttpURL -replace '//*$') + '/blank'
    Invoke-WebRequest -UseBasicParsing -Uri $Blank -TimeoutSec 1 > $null
    sleep 10
}

[pscustomobject]@{
    Listerner=$listener | select *
    Routes=$routes
    Form=$form
} | select * 

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

  if ($pattern -eq 'GET /abort') {$listener.Stop()}
  elseif ($route -eq $null) {
    $response.statuscode = 404
    Out-Log_WS -Message "Not found: $pattern" `
    -Data ([pscustomobject]@{
        Route=$Route
        Pattern=$pattern
    })
  } else {
    $route
    [string]$content = & $route
    Out-Log_WS -Message "New request: $pattern" `
    -Data ([pscustomobject]@{
        Route=$Route
        Pattern=$pattern
        Content=$content
    })

    $buffer = [system.text.encoding]::utf8.getbytes($content)
    $response.contentlength64 = $buffer.length
    $response.outputstream.write($buffer, 0, $buffer.length)
  }

  if ($pattern -ne 'GET /abort') {$response.close()}
  . reload
}

$listener.Stop()
$listener.Prefixes.Clear()
$listener.Dispose()
}

if ($LoadVariables) {return (Write-Verbose -Verbose -Message "-LoadVariables was specified, so the script is ending after creating initial variables.")}

stop-job -Name $ScriptName -ErrorAction SilentlyContinue
if ($RunInProcess) {
    . $HTTPListenerScriptBlock | %{$_;write-warning "Remember to navigate to $($url[0])/abort to stop this script propperly!!!!"}
}
ELSE {
    start-job -Name $ScriptName -ScriptBlock $HTTPListenerScriptBlock
    Watch-Job_DOES
}