Function Get_userProfile {
    if (($Script:AuthenticationSchemes -eq 'Basic') -and $global:context.User.Identity.Name -and $global:context.User.Identity.Password)
    {
        $global:context.User.Identity.Name
        $UserName = $global:context.User.Identity.Name -split '\\' | select -First 1 -Skip 1
    }
    #ELSE
    #Get_UserSession
}
