Step 1 : Configure
 - Use config to configure your server (server, port, url)
 - sessionId for databasePrepare (create a session with a long duration)
 - UserToAdd if need to add user after a restore



Step 2 : SQL 
 - Open Sql Management studio and execute the xpcmdshell (**)

Step 3 : Powershell
 - Open a powershell in Administrator 
 - Set-ExecutionPolicy Unrestricted

Step 4 : open restore LastBackup
 - Open the powershell in Administrator (*) and Execute
 - Better to use ise (Powershell debugger)


(*) Add the possibility to Run Powershell as Admin from contextual Menu
# To ADD possibility to Run As Admin Powershell
New-Item -Path "Registry::HKEY_CLASSES_ROOT\Microsoft.PowershellScript.1\Shell\runas\command" `-Force -Name '' -Value '"c:\windows\system32\windowspowershell\v1.0\powershell.exe" -noexit "%1"'
  

(**)

-- To allow advanced options to be changed.
EXEC sp_configure 'show advanced options', 1
GO
-- To update the currently configured value for advanced options.
RECONFIGURE
GO
-- To enable the feature.
EXEC sp_configure 'xp_cmdshell', 1
GO
-- To update the currently configured value for this feature.
RECONFIGURE
GO