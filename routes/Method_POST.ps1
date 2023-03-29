$form = render $form @{html = $html}

Set-ResponseAuthentication_WS -UserName $Data['username'] -password $Data['password']
$Authentication = Get-ResponseAuthentication_WS
$decoded = ConvertFrom-Jwt -Token $Authentication.CookieValue

# get post data.
$data = extract $request

# get the submitted name.
$html +=  Convert-ObjectToHTMLTable -as LIST [pscustomobject]$data

[string]$HTML += . {
    Convert-ObjectToHTMLTable -InputObject $Authentication -AS LIST -VariableName Authentication
    '<br>'
    Convert-ObjectToHTMLTable -InputObject $request -as LIST -VariableName Request
    '<br>'
    Convert-ObjectToHTMLTable -InputObject $decoded -as LIST -VariableName Decoded
}

$form = gc  "$PSScriptRoot\form.html"
# render the 'FormResponse' snippet, passing the name.
$page = render $form @{html = $html}

# embed the snippet into the template.
return (render ((gc (Get-HTMLTemplate_WS)) -join "`r`n") $page)
        
