Function Get_LogonInformation {
#OptimizeThis 
#ToDo 
#Write a cacheing table to store ReverseDNSLookupAsynch and periodically check ReverseDNSLookupAsynch.GetAwaiter().iscompleted
    param (
        $FollowUpObject
    )
    if ($FollowUpObject)
    {
        if ($ReverseDNSLookupAsynch.GetAwaiter().iscompleted)
        {
            $Reverse = $ReverseDNSLookupAsynch.Result
            if ($Reverse -ne $null)
            {
                Get-Member -InputObject $Reverse -MemberType Properties | ?{$_.name} | %{
                    $P = $_.Name
                    Add-Member -MemberType NoteProperty -InputObject $Record -Name "RDNSLU_$P" -Value $Reverse.($P)
                    $Record.isDNSRLUComplete=$True
                }
            }
        }
        return
    }
    $IP = try{$global:context.Request.RemoteEndPoint.ToString()}catch{}
    if($IP)
    {
        $ReverseDNSLookupAsynch = ([System.Net.Dns]::GetHostEntryAsync($IP))
        $Record = try {Get-GeoIP $global:context.Request.RemoteEndPoint.ToString()}catch{}
    }
    if (-not $Record.ip)
    {
        $Record = new-object psobject -Property @{
            IP=''
            CountryCode=''
            CountryName=''
            RegionCode=''
            RegionName=''
            City=''
            ZipCode=''
            TimeZone=''
            Latitude=''
            Longitude=''
            MetroCode=''
            ReverseDNSLookupAsynch=$ReverseDNSLookupAsynch
            isDNSRLUComplete=$False
        }
    }
    ELSE
    {
        Add-MemberValue -Inputobject $Record -Name ReverseDNSLookupAsynch -Value $ReverseDNSLookupAsynch
        Add-MemberValue -InputObject $Record -Name isDNSRLUComplete       -Value $False
    }
    if ($Get_LogonInformation_CompleteDNSLR -eq $null)
    {
        New-Variable -Name Get_LogonInformation_CompleteDNSLR -Option AllScope -Force -Value { #ToDo #make Constant
        if (-not $This.isDNSRLUComplete) 
        {
            Get_LogonInformation -FollowUpObject $This
        }
        ELSE
        {
            Write-Error -Message 'DNSLR is already completed' -Category InvalidOperation
        }
    }
    $Record | Add-Member -MemberType ScriptMethod -Force -Name CompleteDNSLR -Value $Get_LogonInformation_CompleteDNSLR -PassThru
    $I = 0 
    Get_LogonInformation -FollowUpObject $Record
    $Record
    }
}
