
# Remove all jobs before we start our process
$prefixjob = "PJobDP"
$batch =  @(Get-Job | Where-Object {$_.name -like "$prefixjob*" })
$batch | Remove-Job


$outputFile = $PSScriptRoot + "\results_" + $prefixjob + "_jobs.log"
write-host "Script result at this location : " $outputFile


# Do a process for 1 to 20
for($i=1
     $i -le 20
     $i++){
    $running = @(Get-Job | Where-Object { $_.State -eq 'Running' -and $_.name -like "$prefixjob*" })
    if ($running.Count -le 8) {
        
        $jobname = $prefixjob + $i

        Start-Job -Name $jobname -ArgumentList $i,$outputFile {

             write-host $args[0] $args[1] 
             $temp = "Job " + $args[0] + " is working "
             
             $rnd = Get-Random -Minimum 1 -Maximum 10
             Start-Sleep -Seconds $rnd

             #ac "$PSScriptRoot/resultJobs.log" $temp
             Add-Content -Path $args[1]  -Value $temp

             #$file_path = "$PSScriptRoot/resultJobs.log"
             #$sw = New-Object -typename System.IO.StreamWriter($file_path, "true")
             #$sw.WriteLine($temp)
             #$sw.Close()
        }
    } else {
         $running | Wait-Job
    }
    Get-Job | Receive-Job
}