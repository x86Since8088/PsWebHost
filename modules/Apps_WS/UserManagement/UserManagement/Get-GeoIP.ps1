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
    return
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
            ($IP -eq '::1') -or 
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
                [array]$V=$Global:GeoIPTable[$IP]
                if($V.count -eq 0)
                {
                    $Global:GeoIPTable.add($IP,$Global:GeoIPArray.add((new-object psobject -property @{IP=$IP})))
                }
                ELSE
                {
                    $Global:GeoIPTable[$IP]=$V + $Global:GeoIPArray.add((new-object psobject -property @{IP=$IP}))
                }
                return
            }
        }
        } | ?{$_.IP} | %{
            $Global:GeoIPTable.add($IP,$Global:GeoIPArray.add($_))
            return $_
        }
    }
}