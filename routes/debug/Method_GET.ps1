param (
    $context=$Global:context
)
cls
    Write-Host $PSScriptRoot
    $Request = $context.request
    $Form = Get-Content ((Split-Path $MyInvocation.MyCommand.Definition) +'\Form.html')
    $Myresponse = '' +
    '<title>Debug</title>' +
    '<H1>Debug</h1>' +
    $form + '<br>' +
    (Convert-ObjectToHTMLTable -VariableName Request -InputObject $Request -AS LIST)

    #$page = render $Myresponse @{name = $name}
    $page = $Myresponse

    # embed the snippet into the template.
    return (render (Get-Content (Get-HTMLTemplate_WS)) $page)

#return (render $template $form)
