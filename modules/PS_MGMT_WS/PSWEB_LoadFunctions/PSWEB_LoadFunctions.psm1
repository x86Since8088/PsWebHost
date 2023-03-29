Function Import-PSWEBFunctions {
     $Files = @()
     if (test-path alias:\listener) {remove-item alias:\listener}
     . "$Global:Project_Root\_Listener\Listener.ps1" 
    'Function Scripts'
     $Files += (Get-ChildItem "$Global:ProjectRoot\_Functions" *.ps1)
     $Files += (Get-Item "$Global:ProjectRoot\_Router\Router.ps1")
    Get-WebHostCacheFileItem $Files.fullname | 
    Where-Object {$_.Event -match 'Read File'} | 
    ForEach-Object {
        Write-Verbose "Reloading $($_.fullname)"
        $_
        . $_.Fullname
    }

    'Modules'
    Get-Module -ListAvailable -Name PSWEB*

    "Commands"
    Get-Command -Module PSWEB*
}