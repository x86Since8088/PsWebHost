Function Invoke_Indexing {
    if (-not (Test-Path "$Global:ScriptFolder\Index"))
    {
        md "$Global:ScriptFolder\Index"
    }
    if (-not (Test-Path "$Global:ScriptFolder\Index\AccountnumberLookup"))
    {
        md "$Global:ScriptFolder\Index\AccountnumberLookup"
    }
    $EmailIndexfile = "$Global:ScriptFolder\Index\AccountnumberLookup\Email_AccountNam.index"
    $script:AccLookup_Email = Import-Csv $EmailIndexfile
    gci "$Global:ScriptFolder\Index\WebUserProfiles" | ?{$_.name} | %{
        $R = Import-Clixml $_.fullname | select email,'Account Number'
        #$hash = (Get_Hash -text $r.Email -algorithm SHA1)
        if (-not ($script:AccLookup_Email|?{$_.email -eq $R.email})) 
        {
            $script:AccLookup_Email = $script:AccLookup_Email + (new-object psobject -Property @{Email=$R.email;'Account Number'=$R.'Account Number'})
            """$($R.email)"",$($R.'Account Number')"""|out-file -FilePath $EmailIndexfile -Encoding unicode
        }
            
    }

}
