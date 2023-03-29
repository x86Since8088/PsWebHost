Function ConvertTo-HTMLJobTile {
    Begin {
    }
    Process{
        $_ | Where-Object{$_.id} | ForEach-Object{
            $Job = $_
            $Job.ChildJobs | Where-Object{$_.id} | ForEach-Object{
                $ChildJob = $_;
                $Progress = ($ChildJob.progress | Where-Object{$_}) | Select-Object -Last 1
                $ChildJob
            } | Select-Object Location,Name,
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