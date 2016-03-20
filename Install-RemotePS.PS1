$ip=get-WmiObject Win32_NetworkAdapterConfiguration|Where {$_.Ipaddress.length -gt 1} 
$HostIpAddress = $ip.ipaddress[0] 
Enable-PSRemoting -Force
netsh advfirewall firewall add rule name="WinRM-HTTPS" dir=in localport=5986 protocol=TCP action=allow
$c = New-SelfSignedCertificate -DnsName $HostIpAddress -CertStoreLocation cert:\LocalMachine\My
winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"$($HostIpAddress)`";CertificateThumbprint=`"$($c.ThumbPrint)`"}"
netsh advfirewall firewall add rule name="WinRM-HTTPS" dir=in localport=5986 protocol=TCP action=allow

#TEST using non domain
Test-NetConnection IP -Port  5986
$options = New-PSSessionOption -SkipCACheck -SkipCNCheck
Enter-PSSession –ComputerName IP –Credential $cred -UseSSL -SessionOption $options

#TEST using  domain user
[object] $objCred = $null
[string] $strUser = 'Domain\user'
$strPass = ConvertTo-SecureString -String "password" -AsPlainText -Force
$objCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ($strUser, $strPass)
$s = New-PSSession -ComputerName SERVER -Credential $objCred
#Invoke-Command -Session $s -ScriptBlock {$services = Get-Service}
#Invoke-Command -Session $s -ScriptBlock {$services | Where-Object {$_.Status -eq "Stopped"}}
#Invoke-Command -Session $s -ScriptBlock {}


Invoke-Command -Session $s -ArgumentList $env:1,$env:2  -ScriptBlock {
        param($1,$2) 
        Write-Host "1 : " " => " $1
        Write-Host "2 : " " => " $2
        Set-Location C:\Folder\otherFolder
        
        $gconf = gc config.json | Out-String | ConvertFrom-JSON	
        $gconf.1 = $1
        $gconf.2 = $2
        
        $resuSC = $gconf  |  ConvertTo-Json -Depth 999 | Out-String 
        $resuSC | Set-Content  -path "config_gulp_NEW.json"
        
        cmd /c commandfile_gulp.cmd
        
        #Check if after delivery service is still On 
        $services = Get-Service | Where-Object {$_.Name -eq "oneService"}
        if($services.Status -eq "Running"){
            write-host -ForegroundColor Green $services.Name " = " $services.Status
        }else{
            write-host -ForegroundColor Red $services.Name " = " $services.Status
        }
}


 
