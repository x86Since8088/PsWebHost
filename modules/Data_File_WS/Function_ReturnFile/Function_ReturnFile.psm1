    Function ReturnFile {
        param(
            [string]$URLPath = $Global:LocPath
        )
        $LocalPath = "$global:Project_Root" + ($URLPath -replace '\/','\')
        
        get-content -Encoding byte ($LocalPath)
    }
