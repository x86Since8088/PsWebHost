Function Get-BaselineScan_WS {
    param (
        [bool]$Apply<###Apply###>,
        [string]$Title<###Title###>,
        [string]$VulnerabilitySolution<###VulnerabilitySolution###>,
        [hashtable[]]$Criteria<###Criteria###>,
        [switch]$Testing,
        [switch]$Summary
    )
    if (
        ($Title -eq '') -and 
        ($Criteria.count -eq 0) -and 
        -not $Testing
    ) {return}

    #Set up OS name scoring.
    if ($Global:OperatingSystemHT -eq $null) {
        $Global:OperatingSystemHT=@{};
        $OS=Get-WmiObject win32_operatingsystem -Property *;
        (
            $OS.caption -split '\s'|
            Where-Object{$_ -ne $Null}
        ),$OS.OSArchitecture|
            Where-Object{$Global:OperatingSystemHT[$_] -eq $null}|
            ForEach-Object{$Global:OperatingSystemHT.add($_,$True)}
        if ($OS.OSArchitecture -eq '64-bit') {$Global:OperatingSystemHT.add('x86_64',$True)}
        $Global:OperatingSystemHT.add($OS.BuildNumber,$True)
    }

    #Find the part of the Vulnerbility solution that applies the closest to this system.
    $MatchingBlockFromVulnerabilitySolution=$VulnerabilitySolution -split '\n*\n\s*\*\s\s*' | ForEach-Object{
        $_ -split '\n\s*'|Where-Object{$_ -ne $Null}| select -First 1 | ForEach-Object{
            [string[]]$FirstlineofBlock=$_ -split ',';
            $CandidateOS=$FirstlineofBlock|Where-Object{
                #Make sure the candidate OS' number matches teh current oss number
                $OSSplit=$_ -split '\s'
                [string]$OSVersionNumber=$OSSplit |
                    Where-Object{$_ -match '^\d\d*$'}|
                    select -First 1
                if ($OSVersionNumber -ne '')
                {
                    $Global:OperatingSystemHT[$OSVersionNumber]
                }
            }|ForEach-Object{
                $CandidateOSString=$_
                new-object psobject -Property @{
                    Score=($CandidateOSString -split '\s|\(|\)|\[|\]' |Where-Object{$_ -ne $Null}|ForEach-Object{$Global:OperatingSystemHT[$_]}).count - $OSSplit.count
                    CandidateOSString=$CandidateOSString
                }
            } | sort Score -Descending | select -First 1
        }

        new-object psobject -Property @{
            OSName=$CandidateOS.CandidateOSString
            Score=$CandidateOS.Score
            Text=$_ -split '\n' | select -Skip 1
        }
    } | sort score -Descending | select -First 1

    #Carve the vulnerability sulution text down to just the text for this OS or as close as possible.
    if ($MatchingBlockFromVulnerabilitySolution.Score -gt -2) {
        $VulnerabilitySolution=$MatchingBlockFromVulnerabilitySolution.Text
        [string[]]$DownloadLink=($VulnerabilitySolution -split '\n' | Select-String -SimpleMatch 'Download and apply the patch from:') -replace '^.*?(http|ftp)','$1' -replace '\s\s*$'
    }
    $isInstalled=$null
    [string[]]$KB=$VulnerabilitySolution -split '\(|\)|\s|\n' | Where-Object{$_ -match '^KB\d'} | sort -Unique
    if ($Global:Win32_QuickFixEngineeringHT -eq $null) {$Global:Win32_QuickFixEngineeringHT = @{}}
    if ($KB.count -ne 0)
    {
        $Global:Win32_QuickFixEngineering=Get-WmiObject -Class Win32_QuickFixEngineering 
        $Global:Win32_QuickFixEngineering | sort HotFixID -Unique | Where-Object{$Global:Win32_QuickFixEngineeringHT[$_.HotFixID] -eq $null} | ForEach-Object{$Global:Win32_QuickFixEngineeringHT.Add($_.HotFixID,$_)}
    }
    [array]$isInstalled=$KB | ForEach-Object{$Global:Win32_QuickFixEngineeringHT[$_]} | Where-Object{$_ -ne $null}

    [bool]$Pass=$False
    [array]$Fail=@()
    if ($KB.Count -eq 0) {}
    if ($isInstalled.count -eq 0) {$Fail += 'KB is not installed.'}
    $ErrorData=@()
    $Recording=@()
    $Fail=@()

    foreach ($CriteriaItem in $Criteria)
    {
        $Remediated=$Null
        [string]$Score=''
        if ($CriteriaItem['Name']       -eq $null) {Write-Error   -Message "Missing Name=[string] in -Criteria [hashtable[]] $Criteria"}
        if ($CriteriaItem['Test']       -eq $null) {Write-Error   -Message "Missing Test=[scriptblock]{} in -Criteria [hashtable[]] $Criteria"}
        if ($CriteriaItem['Evaluation'] -eq $null) {Write-Error   -Message "Missing Evaluation=[scriptblock]{} in -Criteria [hashtable[]] $Criteria"}
        if ($CriteriaItem['Remediate']  -eq $null) {Write-warning -Message "Missing Remediate=[scriptblock]{} in -Criteria [hashtable[]] $Criteria"}
        [array]$TestOutput=.{try{. $CriteriaItem['Test']} catch{$ErrorData+=$_}}
        [BOOL]$Pass=[BOOL](. $CriteriaItem['Evaluation'])
        if ((-not $Pass) -and $Apply) {
            Write-Warning "Remediating '$title' item '$($CriteriaItem['Name'])'"
            
            $Error.Clear()
            $Remediated=. $CriteriaItem['Remediate']
            $Error | ForEach-Object{$ErrorData+="Error while remediating '$($CriteriaItem['Name'])'`n$($_ | out-string)"}
            [bool]$NATestOutput = . $CriteriaItem['Test']
            $Error.Clear()
            $PostRemediationCheck=. $CriteriaItem['Test']
            $Error | ForEach-Object{$ErrorData+="Error while performing post-remediation check of '$($CriteriaItem['Name'])'`n$($_ | out-string)"}
            
            $Pass=. $CriteriaItem['Evaluation']
        }
        If (-not $Pass)
        {
            $Fail+="Not applied: '$($CriteriaItem['Name'])'"
        }
        if (($Score -eq '') -and ($NATestOutput -eq $True )) {$Score = 'N/A';$PASS = $True}
        if (($Score -eq '') -and ($NATestOutput -eq $False) -and ($Pass -eq $True )) {$Score = 'PASS'}
        if (($Score -eq '') -and ($NATestOutput -eq $False) -and ($Pass -eq $False)) {$Score = 'FAIL'}
            
        $RecordItem = new-object psobject -Property @{
            Computer=$env:COMPUTERNAME
            'Vulnerability Title'=$Title
            Score=$Score
            Pass=$Pass
            Apply=$Apply
            Test=$CriteriaItem['Test']
            Name=$CriteriaItem['Name']; 
            Evaluation=$CriteriaItem['Evaluation']
            Remediate=$CriteriaItem['Remediate']
            PostRemediationCheck=$PostRemediationCheck
            Remediated=$Remediated
            TestOutput=$TestOutput
            NATest=$CriteriaItem['NATest']
            Error=$Error
            Notes=$CriteriaItem['Notes']
        }
        if ($Summary) {
            $Recording += $RecordItem
        }
        ELSE {
            $RecordItem | select Computer,
                PASS,
                Score,
                'Vulnerability Title',
                Name,
                Notes,
                TestOutput,
                Remediated,
                PostRemediationCheck,
                Error
        }
        $Error.clear()
    }
    if ($Summary) {
        new-object psobject -Property @{
            Computer=$env:COMPUTERNAME
            KB=$KB;
            DownloadLink=$DownloadLink
            Apply=$Apply
            'Installed KB'=$isInstalled
            'Vulnerability Title'=$Title
            TestOutput=$TestOutput
            'Post Remediation Check'=$PostRemediationCheck
            Fail=$Fail
            Pass=($Fail.count -eq 0)
            Remediated=$Remediated
            Error=$ErrorData
            Recording=$Recording
            #'Vulnerability Solution'=$VulnerabilitySolution
        } | select PASS,'Installed KB','Vulnerability Title',Fail,Remediated,TestOutput,'Post Remediation Check',DownloadLink,Error,Recording
    }
    #>
}