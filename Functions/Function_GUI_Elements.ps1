$code = @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;

namespace System
{
	public class IconExtractor
	{

	 public static Icon Extract(string file, int number, bool largeIcon)
	 {
	  IntPtr large;
	  IntPtr small;
	  ExtractIconEx(file, number, out large, out small, 1);
	  try
	  {
	   return Icon.FromHandle(largeIcon ? large : small);
	  }
	  catch
	  {
	   return null;
	  }

	 }
	 [DllImport("Shell32.dll", EntryPoint = "ExtractIconExW", CharSet = CharSet.Unicode, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
	 private static extern int ExtractIconEx(string sFile, int iIndex, out IntPtr piLargeVersion, out IntPtr piSmallVersion, int amountIcons);

	}
}
"@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing


function Show-Balloon-Warning{
param (
    [int]$ShowBalloonTip = 10000,
    [string]$BalloonTipTitle = “BalloonTipTitle not specified”,
    [string]$BalloonTipText = “BalloonTipText not specified”,
    #[ValidateSet('Info','Warning','Error')]
    [System.Windows.Forms.ToolTipIcon]$BalloonTipIcon = “Info”,
    [string]$IconFile,
    [int]$IconIndex = $null,
    [switch]$NoDispose,
    [Scriptblock]$DisposalFollowup
)
[void] [System.Reflection.Assembly]::LoadWithPartialName(“System.Windows.Forms”)

    $tray = New-Object System.Windows.Forms.NotifyIcon
    if (-not  $IconFile)
    {
        $IconFile = 'C:\windows\explorer.exe'
        if (-not  $IconIndex)
        {
            $IconIndex = 1
        }
    }
    if ($IconIndex)
    {
        $Tray.icon = [System.Drawing.Icon][System.IconExtractor]::Extract($IconFile, $IconIndex, $true)
    }
    ELSE
    {
        $tray.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($IconFile)
    }
    $tray.BalloonTipIcon = $BalloonTipIcon
    $tray.BalloonTipText = $BalloonTipText
    $tray.BalloonTipTitle = $BalloonTipTitle
    $tray.Visible = $True
    $tray.ShowBalloonTip($ShowBalloonTip)
    $tray
    if (-not $NoDispose)
    {
        Schedule_Disposal -DisposeAfter (get-date).Addseconds(-$ShowBalloonTip - 10) `
            -Object $Tray `
            -AfterDisposalAction $Disposalfollowup
    }
}