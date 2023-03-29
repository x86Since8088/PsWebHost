param (
    $SessionObject=(Get-WebhostSessionObject),
    [switch]$GetApprovedArgs,
    $AppArguments
)
if ($GetApprovedArgs) {return ("App","Run","Navigate","Link","Command",'ParamReset','ParamName','ParamAdd','ParamRemove')}
