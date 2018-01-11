Function ConvertTo-HTMLJobTile {
    Begin {
    }
    Process{
        $_ | ?{$_.id} | %{
            $Job = $_
            #$ProgressBar = 
            $Job.ChildJobs | ?{$_.id} | %{
                $ChildJob = $_;
                $Progress = ($_.progress | ?{$_})[-1]
                $_
            } | select Location,Name,
                ID,
                JobState,
                @{n='Action';e={$Progress.Action}},
                @{n='StatusDescription';e={$Progress.StatusDescription}},
                @{n='PercentComplete';e={$Progress.PercentComplete}},
                @{n='Data';e={Receive-Job -id $ChildJob.id}}
        } | Write_HTable
    }
    End{
    }
}