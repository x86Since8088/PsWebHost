Function ManageRunSpaces {
    <#
    .Link http://nivot.org/post/2009/01/22/CTP3TheRunspaceFactoryAndPowerShellAccelerators
    .Note
    To do: Translate all "+=" related items and their logic to system.collections.arraylist logic for powershell v3+ compatibility.
    .Note
    To do: Translate all "+=" related items and their logic to system.collections.arraylist logic for powershell v3+ compatibility.

    #>
    param (
        [int]$ManageRunSpaces_RunspaceCount
    )
    if ($ManageRunSpaces_RunspaceCount)
    {
        
    }
    $Script:ManageRunSpaces_RunspaceCount
    require -version 2.0   
    # create a pool of 3 runspaces  
    $Script:ManageRunSpaces_pool = [runspacefactory]::CreateRunspacePool(1, 3)
    $Script:ManageRunSpaces_pool.Open()
    write-host "Available Runspaces: $Script:ManageRunSpaces_($Script:ManageRunSpaces_pool.GetAvailableRunspaces())"  
    $Script:ManageRunSpaces_jobs = @()   
    $Script:ManageRunSpaces_ps = @()   
    $Script:ManageRunSpaces_wait = @()  
    # run 6 background pipelines  
    for ($Script:ManageRunSpaces_i = 0; $Script:ManageRunSpaces_i -lt 6; $Script:ManageRunSpaces_i++) {  
     
       # create a "powershell pipeline runner"  
       $Script:ManageRunSpaces_ps += [powershell]::create()  
     
       # assign our pool of 3 runspaces to use  
       $Script:ManageRunSpaces_ps[$Script:ManageRunSpaces_i].runspacepool = $Script:ManageRunSpaces_pool 
     
       $Script:ManageRunSpaces_freq = 440 + ($Script:ManageRunSpaces_i * 10)  
       $Script:ManageRunSpaces_sleep = (1 * ($Script:ManageRunSpaces_i + 1))  
     
       # test command: beep and wait a certain time  
       [void]$Script:ManageRunSpaces_ps[$Script:ManageRunSpaces_i].AddScript(  
            "[console]::Beep($Script:ManageRunSpaces_freq, 30); sleep -seconds $Script:ManageRunSpaces_sleep")  
     
       # start job  
       write-host "Job $Script:ManageRunSpaces_i will run for $Script:ManageRunSpaces_sleep second(s)" 
       $Script:ManageRunSpaces_jobs += $Script:ManageRunSpaces_ps[$Script:ManageRunSpaces_i].BeginInvoke();  
     
       write-host "Available runspaces: $Script:ManageRunSpaces_($Script:ManageRunSpaces_pool.GetAvailableRunspaces())" 
     
       # store wait handles for WaitForAll call  
       $Script:ManageRunSpaces_wait += $Script:ManageRunSpaces_jobs[$Script:ManageRunSpaces_i].AsyncWaitHandle  
    }  
 
    # wait 20 seconds for all jobs to complete, else abort  
    $Script:ManageRunSpaces_success = [System.Threading.WaitHandle]::WaitAll($Script:ManageRunSpaces_wait, 20000)  
 
    write-host "All completed? $Script:ManageRunSpaces_success" 
 
    # end async call  
    for ($Script:ManageRunSpaces_i = 0; $Script:ManageRunSpaces_i -lt 6; $Script:ManageRunSpaces_i++) {  
 
        write-host "Completing async pipeline job $Script:ManageRunSpaces_i" 
 
        try {  
 
            # complete async job  
            $Script:ManageRunSpaces_ps[$Script:ManageRunSpaces_i].EndInvoke($Script:ManageRunSpaces_jobs[$Script:ManageRunSpaces_i])  
 
        } catch {  
      
            # oops-ee!  
            write-warning "error: $Script:ManageRunSpaces__" 
        }  
 
        # dump info about completed pipelines  
        $Script:ManageRunSpaces_info = $Script:ManageRunSpaces_ps[$Script:ManageRunSpaces_i].InvocationStateInfo  
 
        write-host "State: $Script:ManageRunSpaces_($Script:ManageRunSpaces_info.state) ; Reason: $Script:ManageRunSpaces_($Script:ManageRunSpaces_info.reason)" 
    }  
 
    # should show 3 again.  
    write-host "Available runspaces: $Script:ManageRunSpaces_($Script:ManageRunSpaces_pool.GetAvailableRunspaces())"  
}
