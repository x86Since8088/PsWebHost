param (
    $HTTPSListenerContext,
    [switch]$GetApprovedArgs,
    $AppArguments
)
if ($GetApprovedArgs) {return ('Logon','Logoff','Navigate','ParamReset','ParamName','ParamAdd','ParamRemove')}

. "$Global:ScriptFolder\Apps\Reload Functions.ps1"|out-null
$UserName = $arguments | ?{$_.name -eq 'UserName'} | %{$_.Value -split "\s|`n|,"} | ?{$_}
$Password = $arguments | ?{$_.name -eq 'Password'} | %{$_.Value -split "\s|`n|,"} | ?{$_}

get-member -InputObject $global:context.Request
$global:context.Request|fl

Write_Tag -Tag form -TagData 'action="Home" method="post" method' -Content (&{
      Write_Tag -Tag input -TagData "type=""hidden"" name=""App"" value=""Logon""" -NoTerminatingTag
      'UserName:<br>'
      Write_Tag -Tag input -TagData "type=""text"" name=""UserName"" value=""$($UserName -join ',')""" -NoTerminatingTag
      '<br>'
      'Password:<br>'
      Write_Tag -Tag input -TagData "type=""password"" name=""Password"" value=""$($Password -join ',')""" -NoTerminatingTag
      '<br>'
      Write_Tag -Tag input -TagData 'type="submit" value="Submit"' -NoTerminatingTag
  
})
$arguments
""
$UserProfile
""
$global:context
""
$global:listener