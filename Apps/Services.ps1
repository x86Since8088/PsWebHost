Param (
  $SessionObject=(Get-WebhostSessionObject),
  $HttpMethod,
  $GetApprovedArgs,
  $InputStreamText
)
if ($GetApprovedArgs) {return ("App","Run","Navigate","Link","Command",'ParamReset','ParamName','ParamAdd','ParamRemove')}
get-service