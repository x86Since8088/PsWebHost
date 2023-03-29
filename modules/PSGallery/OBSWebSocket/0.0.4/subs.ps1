[Flags()] enum Subs {
    NONE = 0
    GENERAL = 1 -shl 0
    CONFIG = 1 -shl 1
    SCENES = 1 -shl 2
    INPUTS = 1 -shl 3
    TRANSITIONS = 1 -shl 4
    FILTERS = 1 -shl 5
    OUTPUTS = 1 -shl 6
    SCENEITEMS = 1 -shl 7
    MEDIAINPUTS = 1 -shl 8
    VENDORS = 1 -shl 9
    UI = 1 -shl 10
    
    INPUTVOLUMEMETERS = 1 -shl 16
    INPUTACTIVESTATECHANGED = 1 -shl 17
    INPUTSHOWSTATECHANGED = 1 -shl 18
    SCENEITEMTRANSFORMCHANGED = 1 -shl 19
}

Function Get-OBSLowVolume {
    return [System.Int32]$(
        [int][Subs]::GENERAL `
            -bor [int][Subs]::CONFIG `
            -bor [int][Subs]::SCENES `
            -bor [int][Subs]::INPUTS `
            -bor [int][Subs]::TRANSITIONS `
            -bor [int][Subs]::FILTERS `
            -bor [int][Subs]::OUTPUTS `
            -bor [int][Subs]::SCENEITEMS `
            -bor [int][Subs]::MEDIAINPUTS `
            -bor [int][Subs]::VENDORS `
            -bor [int][Subs]::UI
    )
}

Function Get-OBSHighVolume {
    return [System.Int32]$(
        [int][Subs]::INPUTVOLUMEMETERS `
            -bor [int][Subs]::INPUTACTIVESTATECHANGED `
            -bor [int][Subs]::INPUTSHOWSTATECHANGED `
            -bor [int][Subs]::SCENEITEMTRANSFORMCHANGED
    )
}

Function Get-OBSAll {
    return [System.Int32]$($(LowVolume) -bor $(HighVolume))
}

Function Get-OBSSubs {
    return [Subs]
}
