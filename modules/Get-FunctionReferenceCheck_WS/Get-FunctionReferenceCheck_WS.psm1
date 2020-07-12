Function Get-FunctionReferenceCheck_WS {
<#
.Synopsis
Created by Edward Skarke to identify source function names that are supported by alias instead of by direct call.
#>
    [array]$Callstack = @(Get-PSCallStack | select -Skip 1 -First 2)
    $TargetFunction = $Callstack[0]
    $CallStackSource = $Callstack[1]
    if ($CallStackSource.Position.Text -notlike "*$($TargetFunction.FunctionName)*") {
        Write-Warning -Message (
            "$($TargetFunction.FunctionName): Please make sure that references like '$($CallStackSource.Position.Text)' are updated to use '$($TargetFunction.FunctionName)'." + 
            "`n|`t"+$TargetFunction.ScriptName + 
            "`n`t|`tTarget Script Location: "+$TargetFunction.Location + 
            "`n`t|`tTarget Script Command: " + $TargetFunction.Command + 
            "`n|`t"+$CallStackSource.ScriptName + 
            "`n`t|`t Source Script Location: "+$CallStackSource.Location + 
            "`n`t|`t Source Script Command: " + $CallStackSource.Position.Text
        )
    }
}