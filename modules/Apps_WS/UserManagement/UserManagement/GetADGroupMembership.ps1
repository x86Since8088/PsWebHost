Function GetADGroupMembership {
    Param (
        [string]$Name,
        [System.Collections.ArrayList]$GroupMembership = (New-Object System.Collections.ArrayList),
        $Searchon = 'samaccountname'
    )
    if ($name)
    {
        ([ADSISEARCHER]"$Searchon=$($Name)").Findone() | ?{$_.Properties} | %{$_.Properties.memberof} | ?{-not $GroupMembership.Contains([string]$_)} | %{
            $GroupMembership.add($_) | out-null
            GetGroupMembership -Name $_ -GroupMembership $GroupMembership -Searchon 'dn' | ?{-not $GroupMembership.Contains([string]$_)} | %{
                $GroupMembership.add($_) | out-null
            }
        }
        $GroupMembership
    }
    ELSE
    {
        Write-Verbose -Message 'ADSI group membership resolution skipped because $Name is Null or blank.'
    }
} 
