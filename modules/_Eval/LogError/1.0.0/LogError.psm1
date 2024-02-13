Function Write-logfile
{
[CmdletBinding()]
param (   
    [Parameter( Mandatory=$true,
                HelpMessage="comment.")]           
    [string]$comment 
    )
BEGIN  
    {
    #Parameters Required For Writing Into Log File
    }
PROCESS
    {
    $message=$comment
    Write-Output $message 
    $logMessage = (Get-Date -Format "dd/MM/yyyy hh:mm:ss")  + (" : ") + ( $message ) + ("`r`n") | Out-File $LogFilePath -Append        
}
END    
    {   }
}
Export-ModuleMember -Function Write-logfile
Function Write-ErrortoLogfile 
{
<#	
		.DESCRIPTION
		 Use this function to log the error message with the exact time stamp.
        .AUTHOR :ATHIRA G RAJAN
        .VERSION:5.1.19041.1320
	#>

[CmdletBinding()]
param (
    
    [Parameter( Mandatory=$false,
                HelpMessage="Exception.")]
    [string]$exception,
     
    [Parameter(Mandatory=$false,
                HelpMessage="Script fails at line number.")]
    [string]$failinglinenumber,

    [Parameter(Mandatory=$false,
                HelpMessage="Failing line looks like.")]
    [string]$failingline
)
BEGIN
    {
    #Parameters Required For Writing Into Log File  
    }
PROCESS
    {   
        #Start Writing into logfile in a a structured manner
        Write-Verbose "Start writing to Error log file.$LogFilePath"
        $timestamp = Get-Date -Format "dd/MM/yyyy hh:mm:ss"
        "   " | Out-File $LogFilePath -Append
        "*************************************************" | Out-File $LogFilePath -Append
        "   " | Out-File $LogFilePath -Append
        "Error happend at time: $timestamp" | Out-File $LogFilePath -Append
        "   " | Out-File $LogFilePath -Append
        "Error exception: $exception" | Out-File $LogFilePath -Append
        "   " | Out-File $LogFilePath -Append
        "Failing at line number: $failinglinenumber" | Out-File $LogFilePath -Append
        "   " | Out-File $LogFilePath -Append
        "Failing at line: $failingline" | Out-File $LogFilePath -Append
        "   " | Out-File $LogFilePath -Append
    }
END
    {
         #Finish writing error into logfile
         Write-Output "Finish writing error into logfile" 
    }
}
Export-ModuleMember -Function Write-ErrortoLogfile
Function Write-ErrorLog 
{
<#	
		.DESCRIPTION
		 Use this function to log the error message with the exact time stamp.
        .AUTHOR :ATHIRA G RAJAN
        .VERSION:5.1.19041.1320
	#>
[CmdletBinding()]
param (
    [Parameter( Mandatory=$false,
                HelpMessage="Exception.")]
    [string]$exception,
    [Parameter(Mandatory=$false,
                HelpMessage="Script fails at line number.")]
    [string]$failinglinenumber,
    [Parameter(Mandatory=$false,
                HelpMessage="Failing line looks like.")]
    [string]$failingline
)
BEGIN
    {
    #Parameters Required For Writing Into Log File
     #Creating logfile
    if(Test-Path -Path $ErrorFilePath)
    {
        # Removing existing  file
        Get-ChildItem -Path $ErrorFilePath -Filter *.txt | Where-Object -Property Name -Match $ErrorFileName| ForEach-Object { Remove-Item -Path $_.FullName }
    }
    Else
    {
        if  ( !( Test-Path -Path $LogFolderPath -PathType "Container" ) ) 
        {
            #Creating new folder
            Write-Verbose "Create error log folder in: $LogFolderPath"
            New-Item -Path $LogFolderPath -ItemType "Container" -ErrorAction Stop -Force
            $comment="Successfully created Logfolder"
            Write-Output "$comment"
            if ( !( Test-Path -Path $ErrorFilePath -PathType "Leaf" ) ) 
            {
                #Creating new logfile
                Write-Verbose "Create error log file in folder $LogFolderPath with name $ErrorFileName"
                New-Item -Path $ErrorFilePath -ItemType "File" -ErrorAction Stop -Force
                $comment="Successfully created error log in $ErrorFilePath"
                Write-Output $comment 
            }
        }  
    } 
    }
PROCESS
    {   
        #Start Writing into logfile in a a structured manner
        Write-Verbose "Start writing to Error log file.$ErrorFilePath"
        $timestamp = Get-Date -Format "dd/MM/yyyy hh:mm:ss"
        "   " | Out-File $ErrorFilePath -Append
        "*************************************************" | Out-File $ErrorFilePath -Append
        "   " | Out-File $ErrorFilePath -Append
        "Error happend at time: $timestamp" | Out-File $ErrorFilePath -Append
        "   " | Out-File $ErrorFilePath -Append
        "Error exception: $exception" | Out-File $ErrorFilePath -Append
        "   " | Out-File $ErrorFilePath -Append
        "Failing at line number: $failinglinenumber" | Out-File $ErrorFilePath -Append
        "   " | Out-File $ErrorFilePath -Append
        "Failing at line: $failingline" | Out-File $ErrorFilePath -Append
        "   " | Out-File $ErrorFilePath -Append
    }
END
    {
         #Finish writing error into logfile
         Write-Output "Finish writing error into logfile" 
    }
}
Export-ModuleMember -Function Write-Errorlog
