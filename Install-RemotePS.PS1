$ip=get-WmiObject Win32_NetworkAdapterConfiguration|Where {$_.Ipaddress.length -gt 1} 
$HostIpAddress = $ip.ipaddress[0] 
Enable-PSRemoting -Force
netsh advfirewall firewall add rule name="WinRM-HTTPS" dir=in localport=5986 protocol=TCP action=allow
$c = New-SelfSignedCertificate -DnsName $HostIpAddress -CertStoreLocation cert:\LocalMachine\My
winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"$($HostIpAddress)`";CertificateThumbprint=`"$($c.ThumbPrint)`"}"
netsh advfirewall firewall add rule name="WinRM-HTTPS" dir=in localport=5986 protocol=TCP action=allow