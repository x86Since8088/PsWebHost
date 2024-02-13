Function ReplaceMissingContentItems {
    param (
        [string]$Path,
        [string]$GlobalVariableName,
        [scriptblock]$ScriptBlock = {},
        [string]$Text,
        [string]$Encoding = 'UTF8'
    )
    $SBText = $ScriptBlock.ToString()
    if ($SBText -ne '') { $Text = $SBText }
    split-path $Path | 
    Where-Object { -not (test-path $_) } |
    ForEach-Object { mkdir $_ }
    if (-not (test-path $Path)) {
        $Text | Out-File -Encoding $Encoding -FilePath $Path 
    }
    if ($GlobalVariableName -ne '') {
        New-Variable -Force -Scope global -Name $GlobalVariableName -Value ((Get-Content $Path) -join "`n")
    }
}

if (-not (test-path $Global:Project_Root\routes)) { mkdir $Global:Project_Root\routes }
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
    -ScriptBlock { return (render (Get-Content (Get-HTMLTemplate_WS)) $form) }

#Default /Route_post.ps1
ReplaceMissingContentItems -Path "$Global:Project_Root\routes\Route_POST.ps1" `
    -GlobalVariableName '' `
    -ScriptBlock {
    # get post data.
    $data = extract $request

    # get the submitted name.
    $name = $data.item('person')

    # render the 'FormResponse' snippet, passing the name.
    $page = render $FormResponse @{name = $name }

    # embed the snippet into the template.
    return (render (Get-Content (Get-HTMLTemplate_WS)) $page)
}
