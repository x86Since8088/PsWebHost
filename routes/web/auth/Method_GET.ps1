#routes\web\auth\Method_GET.ps1
param (
    $context=$Global:context,
    [switch]$Fragment
)
cls
[string]$QueryString=$context.response.QueryString


#GET /debug
    $context.request.
    $Request = $context.request
    $Form = gc ((Split-Path $MyInvocation.MyCommand.Definition) +'\Form.html')
    
    (Convert-ObjectToHTMLTable -VariableName Request -InputObject $Request -AS LIST )

    #Single line logon
    $page = render $Myresponse @{
        label = ''
        br = ''
        html = ''
    }

    # embed the snippet into the template.
    return (render $template $page)

#return (render $template $form)
