


function Test-Cred_WS {
           
    [CmdletBinding()]
    [OutputType([String])] 
       
    Param ( 
        [Parameter( 
            Mandatory = $false, 
            ValueFromPipeLine = $true, 
            ValueFromPipelineByPropertyName = $true
        )] 
        [Alias( 
            'PSCredential'
        )] 
        [ValidateNotNull()] 
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()] 
        $Credentials
    )
    . {
        $Domain = $null
        $Root = $null
        $Username = $null
        $Password = $null
      
        If($Credentials -eq $null)
        {
            return
        }
        If($Credentials.UserName -eq 'anonymous')
        {
            return "Anonymous User"
        }
        if ($null -eq $Credentials.Password) {
            return "Null password"
        }
        if ('' -eq ([string]$Credentials.GetNetworkCredential().Password)) {
            return "Blank password"
        }

      
        # Checking module
        Try
        {
            # Split username and password
            
            if ($credentials.GetNetworkCredential().password -match '\S') {
                $Username = $credentials.username
                #$Password = $credentials.GetNetworkCredential().password
  
                # Get Domain
                if ($Password -match '\w') {
                    $Root = "LDAP://" + ([ADSI]'').distinguishedName
                    $Domain = New-Object System.DirectoryServices.DirectoryEntry($Root,$UserName,$credentials.Password)
                }
            }
            else {
                return "Invalid password"
            }
        }
        Catch
        {
            $_.Exception.Message
            Continue
        }
  
        If(!$domain)
        {
            Write-Warning "Something went wrong"
        }
        Else
        {
            If ($domain.name -ne $null)
            {
                return "Authenticated"
            }
            Else
            {
                return "Not authenticated"
            }
        }
    } | Debug_WS
}


