Param (
  $SessionObject=(Get-WebhostSessionObject),
  $HttpMethod,
  $GetApprovedArgs,
  $InputStreamText
)

Write_Tag -Tag li -Content (
        Write_Tag -Tag "A" -TagData "ID='ThisSystem' href=/?App=ThisSystem" -content (
        Write_Tag -Tag "SPAN" -Content "This System"
    )
)
