Function UpdateUserContext {
    if ($global:context.User.Identity.Name -match "\\")
    {
        $global:UserName = $global:context.User.Identity.Name -split "\\" | select -Last 1
        $global:Domain = $global:context.User.Identity.Name -split "\\" | select -First 1
    }
    ELSEIF ($global:context.User.Identity.Name -match "@")
    {
        $global:Domain = $global:context.User.Identity.Name -split "@" | select -Last 1
        $global:UserName = $global:context.User.Identity.Name -split "@" | select -First 1
    }
}


Function Get_Profile {
    param([int64]$AccountNumber)
    $ProfileFile = "$Global:ScriptFolder\Profiles\$AccountNumber.cli.xml"
    if (Test-Path $ProfileFile)
    {
        $Record = Import-Clixml $ProfileFile
        $Record.LogonHistory = ([psobject[]](Get_LogonInformation)) + $Record.LogonHistory | select -First 20
    }
    ELSE
    {
        New-Object psobject -Property @{
            'Screen Name'=([string]$null)
            'Account Name'=([string]$null)
            'First Name'=([string]$null)
            'Last Name'=([string]$null)
            'Account Number'=([int64]$AccountNumber)
            Email=([string[]]$null)
            Skype=([string[]]$null)
            'Google+'=([string[]]$null)
            LinkedIn=([string[]]$null)
            Facebook=([string[]]$null)
            'Home Page'=([string[]]$null)
            'Password Hash'=([string]$null)
            'Linked Accounts'=([int64[]]$null)
            'Email Confirmation'=([string]$Null)
            'Locked Out'=($False)
            Enabled=($True)
            Introduction=([string]$Null)
            Customers=([string]$Null)
            Children=([string]$Null)
            LogonHistory=([psobject[]](Get_LogonInformation))
        }
    }
}

Function Save_Profile {
    param ($Profile)
    $ProfileFile = "$Global:ScriptFolder\Profiles\$($Profile.'Account Number').cli.xml"
    if (-not (test-path "$Global:ScriptFolder\Profiles")) {md "$Global:ScriptFolder\Profiles"}
    if (
        $Profile.'Screen Name' -and
        $Profile.'Account Name' -and
        $Profile.'First Name' -and
        $Profile.'Last Name' -and
        $Profile.'Account Number' -and
        $Profile.Email -and
        $Profile.'Email Confirmation'
    )
    {
        $Profile | Export-Clixml 'Account Number' $ProfileFile
    }
}

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
            Get-Member -InputObject $Reverse -MemberType Properties | ?{$_.name} | %{
                $P = $_.Name
                Add-Member -InputObject $Record -MemberType NoteProperty -Name "RDNSLU_$P" -Value $Reverse.($P) -Force
                $Record.isDNSRLUComplete=$True
            }
        }
        return
    }
    $IP = $global:context.Request.RemoteEndPoint.ToString();
    if($IP)
    {
        $ReverseDNSLookupAsynch = ([System.Net.Dns]::GetHostEntryAsync($IP))
        $Record = Get-GeoIP $global:context.Request.RemoteEndPoint.ToString()
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
        Add-Member -InputObject $Record -MemberType NoteProperty -Name ReverseDNSLookupAsynch -Value ReverseDNSLookupAsynch
        Add-Member -InputObject $Record -MemberType NoteProperty -Name isDNSRLUComplete -Value $False
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

if ($Global:GeoIPTable -eq $null) {$Global:GeoIPTable = @{}}
if ($Global:GeoIPArray -eq $null) {$Global:GeoIPArray = new-object System.Collections.ArrayList}

Function Get-GeoIP {
<#
.Synopsis
Upgraded 1/2/2018 with caching of Geo IPs.
#>
param (
    [string]$IP
)
    $IP = $IP -replace '\[|\]'
    $EncIP=[System.Web.HttpUtility]::UrlEncode($IP)
    $GeoIPTableItem=$Global:GeoIPTable[$EncIp]
    if ($GeoIPTableItem -eq $null)
    {$GeoIPArrayItem=$null}
    ELSE
    {
        $GeoIPArrayItem=$Global:GeoIPArray[$GeoIPTableItem]
    }
    if ($GeoIPArrayItem)
    {
        return $GeoIPArrayItem
    }
    ELSE
    {
        .{if ($IP -like '127.0.0.1')
        {
            if ($GeoIPTableItem){return}
            $R = return ([xml](Invoke-WebRequest "http://freegeoip.net/xml/" -UseBasicParsing).Content).Response
            $R.IP = $IP
            $R
        }
        elseif (
            ($IP -like '192.168*') -or 
            ($IP -like '10.*') -or 
            #172.16.0.0/12 
            ($IP -match '^172\.(1[6-9]|2[0-9]|3[0-2])*') 
        )
        {
            if ($GeoIPTableItem){return}
            Get-GeoIP | %{$R = $_; $R.IP="$EncIP based on $([System.Web.HttpUtility]::UrlDecode($_.ip))";$R}
        }
        ELSE
        {
            try {$Response=[xml](Invoke-WebRequest "http://freegeoip.net/xml/$EncIP" -UseBasicParsing).Content}
            catch{$Response=$null}
            if ($Response)
            {
                $Response.Response
            }
            ELSE
            {
                if ($GeoIPTableItem) 
                {
                    return
                }
                $Global:GeoIPTable.add($IP,$Global:GeoIPArray.add((new-object psobject -property @{IP=$IP})))
                return
            }
        }
        } | ?{$_.IP} | %{
            $Global:GeoIPTable.add($IP,$Global:GeoIPArray.add($_))
            return $_
        }
    }
}

    
Function Get_userProfile {
    
    if (($Script:AuthenticationSchemes -eq 'Basic') -and $global:context.User.Identity.Name -and $global:context.User.Identity.Password)
    {
        $global:context.User.Identity.Name
        $UserName = $global:context.User.Identity.Name -split '\\' | select -First 1 -Skip 1
    }
    ELSEIF ($global:context.User.Identity.Name -like 'CustAuth1_*')
    {
        
    }
    ELSE
    {
        new-object 
    }
}

    
function Get_IndexAccountNumber {
    param ([string]$Email)
    $script:AccLookup_Email | ?{$_.email -eq $email} | %{$_.'Account Number'}
}


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
    gci "$Global:ScriptFolder\Index\Profiles" | ?{$_.name} | %{
        $R = Import-Clixml $_.fullname | select email,'Account Number'
        #$hash = (Get_Hash -text $r.Email -algorithm SHA1)
        if (-not ($script:AccLookup_Email|?{$_.email -eq $R.email})) 
        {
            $script:AccLookup_Email = $script:AccLookup_Email + (new-object psobject -Property @{Email=$R.email;'Account Number'=$R.'Account Number'})
            """$($R.email)"",$($R.'Account Number')"""|out-file -FilePath $EmailIndexfile -Encoding unicode
        }
            
    }

}

Function GetGroupMembership {
    Param (
        [string]$Name,
        [System.Collections.ArrayList]$GroupMembership = (New-Object System.Collections.ArrayList),
        $Searchon = 'samaccountname'
    )
        
    GetADGroupMembership -Name $Name -GroupMembership $GroupMembership 
} 

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

$AppsFolder = "$Script:ScriptFolder\Apps"
if (-not (test-path $AppsFolder)) {md $AppsFolder}
$Apps = gci $AppsFolder *.ps1

Function IsUserMemberOf {
    param(
        $UserName = $global:context.User.Identity.Name,
        [string[]]$GroupCN,
        $Searchon
    )
    if ($UserName -match "@") 
    {
        if (-not $Searchon) {$Searchon = 'userprincipalname'}
    }
    ELSEif ($UserName -match "\\") 
    {
        $UserName = $UserName -split '\\' | select -First 1 -Skip 1
        if (-not $Searchon) {$Searchon = 'samaccountname'}
    }
    ELSE 
    {
        if (-not $Searchon) {$Searchon = 'samaccountname'}
    }
    GetGroupMembership -Name $UserName -Searchon $Searchon |?{$_} | ?{$DN = $_;$N = $_ -replace '^CN=([^,]+).+$','$1'; $GroupCN| ?{($_ -eq $N) -or ($_ -eq $DN)}}
}

    