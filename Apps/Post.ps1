Param (
  $SessionObject=(Get-WebhostSessionObject),
  $HttpMethod,
  $GetApprovedArgs,
  $InputStreamText
)
if ($GetApprovedArgs) {return ("App","Run","Navigate","Link","Command",'ParamReset','ParamName','ParamAdd','ParamRemove')}


#$Reader= new-object System.IO.StreamReader $global:WebRequest.InputStream,$global:WebRequest.ContentEncoding
#$ReaderString = $reader.ReadToEnd() -split '\&'
#$Post = new-object psobject @{CurrentEncoding=$Reader.CurrentEncoding;Data=$Reader.ReadToEnd()}
#$reader.Dispose()


@"
Method,InputStreamText
$HttpMethod,"$($InputStreamText -replace '"','""')"
"@ | ConvertFrom-Csv | ConvertTo-Html

Write_Tag -Tag form -TagData 'action="home?App=PSBreakPoint" method="post"' -Content (&{
  'First name:<br>'
  Write_Tag -Tag input -TagData 'type="text" name="firstname"' -NoTerminatingTag
  '<br>'
  'Last name:<br>'
  Write_Tag -Tag input -TagData 'type="text" name="lastname"' -NoTerminatingTag
  '<br>'
  Write_Tag -Tag input -TagData 'type="submit" value="Submit"' -NoTerminatingTag
  
})
""