Function New-RandomPassword {
    param (
        $Chars=',-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~',
        $Length=25,
        $MinUpperCaseLetters = 3,
        $MinLowerCaseLetters = 3,
        $MinNumbers = 3,
        $MinCapSpecialChars = 3
    )
    #Make a secure password that will meet most secureity standards.
    $PWChars = $Chars -split ''
    do {
        $PasswordGen=((0..($Length - 1))|%{$PWChars[(random -Minimum 0 -Maximum ($PWChars.count - 1))]}) -join ''
    }
    until (
        (($PasswordGen -split '' | ?{$_ -cmatch '[A-Z]'}).count -ge $MinUpperCaseLetters) -and
        (($PasswordGen -split '' | ?{$_ -cmatch '[a-z]'}).count -ge $MinLowerCaseLetters) -and
        (($PasswordGen -split '' | ?{$_ -cmatch '[0-9]'}).count -ge $MinNumbers) -and
        (($PasswordGen -split '' | ?{$_ -match ',|-|\.|/|:|;|<|=|>|\?|@|\[|\\|]|\^|_|`|\{|\||}|~'}).count -ge $MinCapSpecialChars) 
    )
    return $PasswordGen
}