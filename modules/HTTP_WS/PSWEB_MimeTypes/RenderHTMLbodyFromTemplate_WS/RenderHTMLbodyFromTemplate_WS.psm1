# embed content into the default template.
function RenderHTMLbodyFromTemplate_WS($template, $content) {
  # shorthand for RenderHTMLbodyFromTemplate_WSing the template.
  if ($content -is [string]) { $content = @{page = $content} }

  if (-not $content.Contains('sidebar')) {$content.add('sidebar',(Get-SideBarContent_WS))}

  foreach ($key in $content.keys) {
    $template = $template -replace "<replace ID=\{$key\} />", $content[$key]
  }

  $template = ($template -split '({PS{.*?}PS})' | %{
    switch -Regex ($_) {
        '^{PS{.*?}PS}' {
            Invoke-Expression ($_ -replace '^{PS{|}PS}$')
        }
        default {
            $_
        }
    }
  }) -join ''

  return $template
}
new-alias -Force render -Value RenderHTMLbodyFromTemplate_WS