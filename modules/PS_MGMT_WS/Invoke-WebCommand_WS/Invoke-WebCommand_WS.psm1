Function Invoke-WebCommand_WS {
    param (
        $CommandName,
        $Parameters,
        $User
    )
    $ACL = Get-WebCommandACL_WS -CommandName $CommandName -Parameters $Parameters -User $User
}

Function Get-WebCommandACL_WS {
    param (
        $CommandName,
        $Parameters,
        $User,
        $Contect = $Global:Context
    )
    write-warning (
        $MyInvocation.MyCommand.Module.Path + ' ' + 
        $MyInvocation.MyCommand.Definition + ' is not complete.'
    )
    $EncodedCommandName=Encode-URL_WS $CommandName
    $ACLFolder = "$Global:Datafolder\ACL\WebCommandACL"
    $HT = @{}
    #gci $ACLFolder -Filter $b
}