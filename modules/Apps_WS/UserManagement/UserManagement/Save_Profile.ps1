Function Save_Profile {
    param ($WebUserProfile)
    $WebUserProfileFile = "$Global:ScriptFolder\WebUserProfiles\$($WebUserProfile.'Account Number').cli.xml"
    if (-not (test-path "$Global:ScriptFolder\WebUserProfiles")) {md "$Global:ScriptFolder\WebUserProfiles"}
    if (
        $WebUserProfile.'Screen Name' -and
        $WebUserProfile.'Account Name' -and
        $WebUserProfile.'First Name' -and
        $WebUserProfile.'Last Name' -and
        $WebUserProfile.'Account Number' -and
        $WebUserProfile.Email -and
        $WebUserProfile.'Email Confirmation'
    )
    {
        $WebUserProfile | Export-Clixml 'Account Number' $WebUserProfileFile
    }
}