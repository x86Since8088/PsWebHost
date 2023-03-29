Function LogonRequired {
    param (
        $SessionObject = $SessionObject,
        $Context = $PSSessionOption.Context,
        [switch]$GetApprovedArgs,
        $AppArguments
    )
    _p -TagData {test="$sadf"} -innerHTML (.{
        if ($GetApprovedArgs) {return ('Logon','Logoff','Navigate','ParamReset','ParamName','ParamAdd','ParamRemove')}

        if ($ActiveLogon)
        {
            $ActiveLogon
            Get_Cookie_SessionID | Write_Table
            Get_UserSession | Write_Table
        }
        else {
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
            [pscustomobject]@{
                Arguments = $arguments|Write_HTable
                UserProfile = $UserProfile | Write_HTable
                Context = $Context | Write_HTable
                Listener=$Context.listener|Write_HTable
            } | Write_HTable
        }
    })
}