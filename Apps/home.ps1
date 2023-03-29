Param (
  $SessionObject=(Get-WebhostSessionObject),
  $HttpMethod,
  $GetApprovedArgs,
  $InputStreamText
)
switch ($HttpMethod) {
    'get' {if ($GetApprovedArgs) {return ("App","Run","Navigate","Link","Command",'ParamReset','ParamName','ParamAdd','ParamRemove')}}
    'post' {if ($GetApprovedArgs) {return ("App","Run","Navigate","Link","Command",'ParamReset','ParamName','ParamAdd','ParamRemove')}}
    'put' {}

}

if ($GetApprovedArgs) {
    switch ($HttpMethod) {
        get  {return ("App","Run","Navigate","Link","Command",'ParamReset','ParamName','ParamAdd','ParamRemove')}
        post {return ("App","Run","Navigate","Link","Command",'ParamReset','ParamName','ParamAdd','ParamRemove')}
        put  {}
        delete {return }
        options {return }
        default {
            return (
                write-warning -Message "Unhandled HTTP Method '$HttpMethod' on $(
                    ($Myinvocation.Mycommand | Select-Object * | Format-List) -split '\n\s*' | Where-Object{$_}|foreach-object{"`n|`t$_"}
                )"
            )
        }
    }
}

'Hello'

