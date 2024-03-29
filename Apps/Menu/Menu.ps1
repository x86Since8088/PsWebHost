Param (
  $SessionObject=(Get-WebhostSessionObject),
  $HttpMethod,
  $GetApprovedArgs,
  $InputStreamText
)
if ($GetApprovedArgs) {return ("App","Run","Navigate","Link","Command",'ParamReset','ParamName','ParamAdd','ParamRemove')}
"<ul class='menu' style='float:left'>"
"<li><a href='/Home' class='active'><span>Home</span></a></li>"
"<li><a href='/Apps?App=services'><span>Services</span></a></li>"
Write_Tag -Tag li -TagData "class='has-sub'" -Content (
    (Write_Tag -Tag "A" -TagData "href='#'" -content (
        Write_Tag -Tag "SPAN" -Content "About"
    )),
    (Write_Tag -Tag UL -TagData "class='has-sub'" -Content (
        Write_Tag -Tag LI -TagData "class='last'" -CONTENT (
            (Write_Tag -Tag "A" -TagData "href='/Apps?App=ThisSystem'" -content (
                Write_Tag -Tag "SPAN" -Content "Ths System"
            ))
        )
    ))
)
"<li><a href='/Apps?App=Contact'><span>Contact</span></a></li>"
Get-ChildItem "$Global:ProjectRoot\Apps" *.ps1 | Where-Object{-not ($_.name -match '^Menu$')} | ForEach-Object{
    $Appname = $_.name -replace '\.ps1$'
    Write_Tag -Tag "A" -TagData "href='/Apps?App=$Appname'" -content "$Appname<BR>"
}
Write_Tag -Tag li -Content (
    Write_Tag -Tag "A" -TagData "ID='Exit' href=/?command=quit" -content (
        Write_Tag -Tag "SPAN" -Content "Exit"
    )
)
"</ul>"
