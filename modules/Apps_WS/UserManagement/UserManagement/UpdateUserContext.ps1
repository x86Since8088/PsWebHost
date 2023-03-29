Function UpdateUserContext {
    if ($global:context.User.Identity.Name -match "\\")
    {
        $global:UserName = $global:context.User.Identity.Name -split "\\" | select -Last 1
        $global:Domain = $global:context.User.Identity.Name -split "\\" | select -First 1
    }
    ELSEIF ($global:context.User.Identity.Name -match "@")
    {
        $global:Domain = $global:context.User.Identity.Name -split "@" | select -Last 1
        $global:UserName = $global:context.User.Identity.Name -split "@" | select -First 1
    }
}
