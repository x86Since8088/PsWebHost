Function Reload-Modules_WS {
    gci $Global:Project_Modules|gci -Filter *.psm1 | ForEach-Object{
        try {remove-module -ErrorAction SilentlyContinue $_.basename} catch {}
        import-module $_.Fullname -DisableNameChecking -Force
    }
}