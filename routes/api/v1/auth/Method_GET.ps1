$Form=@'
<form method="post" ID="logonform" action="/api/v1/auth">
<span><label for="logon">{label}</label>
<span><input type="text" name="user" value="" placeholder="User" required /></span>
<span><input type="password" name="password" value="" placeholder="password" required /></span>
<span><input type="submit" name="submitlogon" value="Logon" /></span>
</form>
{html}
'@
[string]$HTML = . {
    
}

$form = render $form @{html = $html}

return (render (gc (Get-HTMLTemplate_WS)) $form) 