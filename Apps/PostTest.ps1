Param (
    [switch]$GetApprovedArgs
)
if ($GetApprovedArgs) {return ('PSCommand','WMI Class','ComputerName','App')}
$UserProfile
$GroupMembership = IsUserMemberOf -UserName $global:context.User.Identity.Name -GroupCN "SDN Role Web Author"

#if (-not ($GroupMembership))
#{
#    return "Unauthorized."
#}
$Computername = $arguments | ?{$_.name -eq 'ComputerName'} | %{$_.Value -split "\s|`n|,"} | ?{$_}
if (-not $Computername) {$Computername = $Env:Computername}
$WMIClasses -split ',' | ?{$_} | %{
    $Class = $_
    "get-wmiobject -class $Class -computername $Computername"
    get-wmiobject -class $Class -computername $Computername
} 
$Command = $arguments | ?{$_.name -eq 'PSCommand'} | %{$_.Value} | ?{$_}
$WMIClasses = ($arguments | ?{$_.name -eq 'WMI Class'} | %{$_.Value -split "\s|`n|,"} | ?{$_}) -join ','
Write_Tag -Tag form -TagData 'action="home" method="post" method' -Content (&{
  Write_Tag -Tag input -TagData "type=""hidden"" name=""App"" value=""PostTest""" -NoTerminatingTag
  'ComputerName:<br>'
  Write_Tag -Tag input -TagData "type=""text"" name=""ComputerName"" value=""$($Computername -join ',')""" -NoTerminatingTag
  '<br>'
  'WMI Class:<br>'
  Write_Tag -Tag input -TagData "type=""text"" name=""WMI Class"" value=""$($WMIClasses -join ',')""" -NoTerminatingTag
  '<br>'
  'Command:<br>'
  Write_Tag -Tag TextArea -TagData "type=""textbox"" Rows=10 Cols=80 name=""PSCommand"" wrap='Soft'" -Content ($Command -join ';')
  '<br>'
  Write_Tag -Tag input -TagData 'type="submit" value="Submit"' -NoTerminatingTag
})
""
$arguments | ?{$_.name -eq 'WMI Class'} | %{$_.Value -split "\s|`n|,"} | ?{$_} | %{
    $Class = $_
    "get-wmiobject -class $Class -computername $Computername"
    $error.clear()|out-null
    get-wmiobject -class $Class -computername $Computername
    '<br><b>WMI Errors:</b>'
    $error
} 

$Command | ?{$_} | %{
    "Executing: $_"
    $error.clear()|out-null
    & ([scriptblock]::create($_))
    # | ashtml
    '<br><b>Command Errors:</b>'
    $error
} 

'<B>Interesting WMI Queries</B>'
"Win32_QuickFixEngineering"