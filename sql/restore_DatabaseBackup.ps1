
Function CreateDatabaseIfNotExist([string]$pBaseName, $pServerObject){

    $sQuery = ""
    $sQuery = $sQuery + "if db_id('$pBaseName') is null`r`n"
    $sQuery = $sQuery + "begin`r`n"
    $sQuery = $sQuery + "CREATE DATABASE [$pBaseName] COLLATE French_CS_AS`r`n"
    $sQuery = $sQuery + "end`r`n"

    $resQuery=Invoke-Sqlcmd -Database "master" -Query $sQuery -ServerInstance $pServerObject.Name
    return $resQuery
}

#GET FILE NAME and PATH FOR RESTORE DATABASE
Function Get_MDFLDF([string]$pBaseName, $pServerObject, [ref]$pDFN, [ref]$pDPFN, [ref]$pLFN, [ref]$pLPFN){

    $sQuery="select * from $pBaseName.sys.sysfiles order by fileid"
    $resQuery=Invoke-Sqlcmd -Database "master" -Query $sQuery -ServerInstance $pServerObject.Name

    if($resQuery.count -eq 2){

        #Extract Data and Log File Name and the File Path
        foreach($record in $resQuery)
        {
    
             switch ($record.fileid)
             {
                "1"
                    {
                       [string]$sDataFileName=$record.name
                       [string]$sDataPathFileName=$record.filename

                    }

                "2"
                    {
                       [string]$sLogFileName=$record.name
                       [string]$sLogPathFileName=$record.filename
                    }
                 
              }   
        }
    }

    #write-host $sDataFileName " " $sDataPathFileName " " $sLogFileName " " $sLogPathFileName
    $pDFN.value =$sDataFileName
    $pDPFN.value=$sDataPathFileName
    $pLFN.value=$sLogFileName
    $pLPFN.value=$sLogPathFileName
}

#GET FILE NAME and PATH FOR RESTORE DATABASE
Function Get_LogicalNameFromBackup([string]$pBackupFullPath, $pServerObject,[ref]$pDFN,[ref]$pLFN){

    #$sQuery="restore filelistonly from disk='T:\Scripts\Restore\RestoreBasesFromBlob\backups\Bxx_GEN_DBxxxx_20151024_170006.bak'"
    $sQuery="restore filelistonly from disk='$pBackupFullPath'"

    $resQuery=Invoke-Sqlcmd -Database "master" -Query $sQuery -ServerInstance $pServerObject.Name

    if($resQuery.count -eq 2){
        if($resQuery[0].Type -eq "D"){$pDFN.value = $resQuery[0].LogicalName}
        if($resQuery[0].Type -eq "L"){$pLFN.value = $resQuery[0].LogicalName}
        if($resQuery[1].Type -eq "D"){$pDFN.value = $resQuery[1].LogicalName}
        if($resQuery[1].Type -eq "L"){$pLFN.value = $resQuery[1].LogicalName}
    }else{
        $pDFN.value = ""
        $pLFN.value = ""
    }
}

#GET FILE NAME and PATH FOR RESTORE DATABASE
Function Get_DatabaseListOfUsers([string]$pBaseName, $pServerObject){

$temp_listU=@("user@tata.fr")

    $sQuery="select u.name from $pBaseName.sys.database_principals u where u.name LIKE '%'"
    $resQuery=Invoke-Sqlcmd -Database $pBaseName -Query $sQuery -ServerInstance $pServerObject.Name

    if($resQuery.count -ne 0){
        #Extract Data and Log File Name and the File Path
        foreach($record in $resQuery)
        {
            #write-host $record.name
            $temp_listU += $record.name
        }
    }

    return $temp_listU

}

function FixDatabaseUsersFromList($pListOfUsersToAdd,$pBaseName){

    # ajout des utilisateurs de la liste en parametre
    $sQuery=""

    foreach($curuser in $pListOfUsersToAdd)
    {
        #Create the login if it does not exist
        $sQuery = $sQuery +"IF NOT EXISTS (SELECT * FROM master..syslogins WHERE name = N'$curuser')`r`n"
        $sQuery = $sQuery +"begin`r`n"
        $sQuery = $sQuery +"CREATE LOGIN [$curuser] WITH PASSWORD=N'$curuser', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF`r`n"
        $sQuery = $sQuery +"end`r`n"

        #Create the users with the good sid
	    $sQuery = $sQuery + "IF EXISTS (SELECT * FROM [$pBaseName].sys.database_principals WHERE name = N'$curuser') DROP USER [$curuser]`r`n"
	    $sQuery = $sQuery + "CREATE USER [$curuser] FOR LOGIN [$curuser] WITH DEFAULT_SCHEMA=[dbo]`r`n"
	    $sQuery = $sQuery + "EXEC sp_addrolemember 'db_datareader', '$curuser'`r`n"
	    $sQuery = $sQuery + "EXEC sp_addrolemember 'db_datawriter', '$curuser'`r`n"

    }
    $sQuery = $sQuery + "GO`r`n"

    return $sQuery

}


Function Is_Primary($pServerObject){

    $sQuery = "IF SERVERPROPERTY ('IsHadrEnabled') = 1 `r`n" 
    $sQuery = $sQuery + "BEGIN `r`n"
    $sQuery = $sQuery + "SELECT `r`n"
    $sQuery = $sQuery + "   AGC.name -- Availability Group `r`n"
    $sQuery = $sQuery + " , RCS.replica_server_name -- SQL cluster node name `r`n"
    $sQuery = $sQuery + " , ARS.role_desc  -- Replica Role `r`n"
    $sQuery = $sQuery + " , AGL.dns_name  -- Listener Name `r`n"
    $sQuery = $sQuery + "FROM `r`n"
    $sQuery = $sQuery + " sys.availability_groups_cluster AS AGC `r`n"
    $sQuery = $sQuery + "  INNER JOIN sys.dm_hadr_availability_replica_cluster_states AS RCS `r`n"
    $sQuery = $sQuery + "   ON `r`n"
    $sQuery = $sQuery + "    RCS.group_id = AGC.group_id `r`n"
    $sQuery = $sQuery + "  INNER JOIN sys.dm_hadr_availability_replica_states AS ARS `r`n"
    $sQuery = $sQuery + "   ON `r`n"
    $sQuery = $sQuery + "    ARS.replica_id = RCS.replica_id `r`n"
    $sQuery = $sQuery + "  INNER JOIN sys.availability_group_listeners AS AGL `r`n"
    $sQuery = $sQuery + "   ON `r`n"
    $sQuery = $sQuery + "    AGL.group_id = ARS.group_id `r`n"
    $sQuery = $sQuery + "WHERE `r`n"
    $sQuery = $sQuery + " ARS.role_desc = 'PRIMARY' `r`n"
    $sQuery = $sQuery + "END `r`n"

    $resQuery=Invoke-Sqlcmd -Database "master" -Query $sQuery -ServerInstance $pServerObject.Name

    $retValue = $false 

    foreach($record in $resQuery){
        write-host $record.replica_server_name " is " $record.role_desc " in AG (" $record.name  ")"
        if($record.role_desc -eq "PRIMARY"){
            $retValue = $true 
        }
    }

    return $retValue

}

Function Get-FileNameBak($initialDirectory)
{   
 [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
 Out-Null

 $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
 $OpenFileDialog.initialDirectory = $initialDirectory
 $OpenFileDialog.filter = "Database Backup File (*.bak)| *.bak"
 $OpenFileDialog.ShowDialog() | Out-Null
 $OpenFileDialog.filename
} 
Function Get-DatabaseName($pFullName){
    
    #ex 1 : Bxx_GEN_DBxxx_20151109_081853.bak = on prend GEN_DBxxx
    #ex 2 : GEN_DBxxx.bak = on prend GEN_DBxxx 
    # seul limite pas de 8 caractere apres DBxxx_
    #return $pFullName

    $resu = $pFullName.split("_")
    $retvalue =""
    $check_if_next_val_is_date =$false

    foreach($one in $resu){
        if($check_if_next_val_is_date -eq $true ){
            #20151109
            if($one.length -ne 8){
                $retvalue = $retvalue + "_" + $one
            }
            $check_if_next_val_is_date=$false
        }

        if($one -like "DB*"){
            $retvalue = "GEN_" + $one
            $check_if_next_val_is_date=$true
        }
        
    }

    return $retvalue
}

function RequestURL([string]$pUrl,[int]$pTimeout,[string]$pUserAgent){

    $uri = New-Object "System.Uri" "$pUrl"
    $request = [System.Net.HttpWebRequest]::Create($uri)
    if($pUserAgent -ne ""){
        $request.UserAgent = $pUserAgent
    }
    $request.set_Timeout($pTimeout) #65 second timeout
    $response = $request.GetResponse()
    $reqstream = $response.GetResponseStream() 
    $sr = new-object System.IO.StreamReader $reqstream
    $smsResult = $sr.ReadToEnd()

    return $smsResult

}

function LaunchDatabasePrepare([string]$pDatabase,[string]$pServerURL,[string]$pSessionId){

    $stime=Get-Date;
    $prepare = "DP?dbId=" + $pDatabase 
    $url='http://' + $pServerURL + $prepare + $pSessionId
    $httpStringResult = RequestURL -pUrl $url -pTimeout 120000 -pUserAgent ""
    $etime=Get-Date;
    $stamp=Get-Date -format yyyy-MM-dd-HHmmss
    $temp_resudp= GetDatabasePrepareResult($httpStringResult)

    $tempresu = "`r`n=================================="
    $tempresu= $tempresu + ("`r`n Prepare Result $pDatabase       = " +$temp_resudp)
    $tempresu= $tempresu + ("`r`n Server      = " + $pServerURL)
    $tempresu= $tempresu + ("`r`n Exec Time(s)= " + (($etime - $stime).TotalSeconds))
    $tempresu= $tempresu + ("`r`n Date        = " + $stamp)
    $tempresu= $tempresu + ("`r`n==================================") 
    return $tempresu

}

function GetDatabasePrepareResult([string]$pHttpStringResult){
    $done_resu = "*""done"":1*"
    $total_resu = "*""total"":1*"

    if(($pHttpStringResult -like $done_resu ) -and ($pHttpStringResult -like $total_resu )){
        return "OK SUCCESS (Done=1, Total=1)"
    }else{
        return "KO ERROR (maybe missing)"
    }

}

#load assemblies 
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.Smo.AvailabilityReplica") | Out-Null
[void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
$a = new-object -comobject wscript.shell


# check if Admin
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")){   
  Echo "This script needs to be run As Admin"
  $a.popup("This script needs to be run As Administrator",0,"Restore Modele need to run As Administrator")
  Break
}

# PARAMETRE = INPUT
# CHOOSE ENV + SERVER
try{
    $strFileToLoad  = "$PSScriptRoot\conf.json"
    $conf = Get-Content $strFileToLoad | Out-String | ConvertFrom-JSON	
}catch
{
    Write-Host -ForegroundColor RED "FATAL ERROR : Unable to load configuration file ($PSScriptRoot\conf.json) " $_.Exception.Message
    break;
}

$envCibleServer = $conf.serverCible 
[string]$SQLName=$conf.serverCible + "\" + $conf.serverCibleSQLName 
[string]$sPort = $conf.serverCibleSQLPort 
$add_ListOfUsers= $conf.Users2Add_enable 
$list_of_users_to_add=$conf.Users2Add

$serverURL = $conf.serverURL # 
$idsession= $conf.serverSessionId #

$list_of_users=@()
$backup_folder = "$PSScriptRoot\backups"

if(!(Test-Path -Path $backup_folder )){
    $a.popup("You must put all backup file (*.bak) in the backup folder`r`n Creating the folder : $backup_folder `r`n `r`n Please put your backup in this folder before next execustion !!!",0,"Need Backup Folder (With All .bak)")
    New-Item -ItemType directory -Path $backup_folder
    break;
}

$arr_dbtorestore= (Get-ChildItem -Path $backup_folder  | where {$_.extension -eq ".bak"})

# Copy Item should be before or it will not work  .... 
Import-Module "sqlps" –DisableNameChecking
$Connection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection($SQLName+","+$sPort)
#$Connection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection($SQLName)
$Connection.StatementTimeout=0
$serverObject = New-Object Microsoft.SQLServer.Management.SMO.Server($Connection) 

write-host -ForegroundColor Green $serverObject.name " PERFORMING RESTORE ..."

foreach($onedbtorestore in $arr_dbtorestore){
    $sRestoreTime=Get-Date;
    write-host  -ForegroundColor Green ("START : Restoring Database = " + $onedbtorestore + " @ " + $sRestoreTime)
    
    $sFilePathToRestore = ($backup_folder + "\" +  $onedbtorestore).ToUpper()
    $sFullBaseName = (split-path $sFilePathToRestore -Leaf).Replace(".BAK","")
    $sBaseName =  Get-DatabaseName -pFullName $sFullBaseName

	try{

if($true -eq $true){

        $sDataFileName=""
        $sDataPathFileName=""
        $sLogFileName=""
        $sLogPathFileName=""
        # Create the database if it does not exist to make sure that it is ok 
        CreateDatabaseIfNotExist -pBaseName $sBaseName -pServerObject $serverObject
        # Get the data and log path for restore without a problem (renaming database 1999 to 1000) 
        Get_MDFLDF -pBaseName $sBaseName -pServerObject $serverObject -pDFN ([ref]$sDataFileName) -pDPFN ([ref]$sDataPathFileName) -pLFN ([ref]$sLogFileName) -pLPFN ([ref]$sLogPathFileName)
        write-host "DATA => " $sDataFileName " " $sDataPathFileName
        write-host "LOGS => " $sLogFileName " " $sLogPathFileName

        #######################################
        # SINGLE USER + OFFLINE + RESTORE + ONLINE +  MULTI USER
        ########################################
        Write-Host  -ForegroundColor Green "RESTORING DATABASE $sBaseName"
        $sDataLogicalFileName=""
        $sLogsLogicalFileName=""
        Get_LogicalNameFromBackup -pBackupFullPath $sFilePathToRestore -pServerObject $serverObject.Name -pDFN ([ref]$sDataLogicalFileName) -pLFN ([ref]$sLogsLogicalFileName)

        $sQuery= "USE master`r`n"
        $sQuery= $sQuery + "ALTER DATABASE $sBaseName SET SINGLE_USER WITH ROLLBACK IMMEDIATE`r`n"
        $sQuery = $sQuery + "ALTER DATABASE $sBaseName SET OFFLINE WITH ROLLBACK IMMEDIATE`r`n"
        $sQuery = $sQuery + "RESTORE DATABASE $sBaseName FROM DISK = '$sFilePathToRestore' WITH REPLACE, `r`n"
        #$sQuery = $sQuery + "MOVE '$sDataFileName' TO '$sDataPathFileName', MOVE '$sLogFileName' TO '$sLogPathFileName' `r`n"
        $sQuery = $sQuery + "MOVE '$sDataLogicalFileName' TO '$sDataPathFileName', MOVE '$sLogsLogicalFileName' TO '$sLogPathFileName' `r`n"
        $sQuery = $sQuery + "ALTER DATABASE $sBaseName SET ONLINE`r`n"
        $sQuery = $sQuery + "ALTER DATABASE $sBaseName SET MULTI_USER`r`n"
        $sQuery = $sQuery + "GO`r`n"
        $resQueryRestore=Invoke-Sqlcmd -QueryTimeout 65535 -Database $sBaseName -Query $sQuery -ServerInstance $serverObject.Name
            
        #############################################
        # Recuperation des users existant de la base
        ##############################################
        Write-Host  -ForegroundColor Green "GETTING EXISTING DATABASE USERS : $sBaseName"
        $list_of_users=@()
        $list_of_users = Get_DatabaseListOfUsers -pBaseName $sBaseName -pServerObject $serverObject

        #############################################
        # Ajout de users QA/SUPPORT
        ##############################################
        if($add_ListOfUsers -eq $true){
            Write-Host  -ForegroundColor Green "ADDING USERS ON DATABASE (QA,SUPPORT,...) : $list_of_users_to_add"
			foreach($oneAdd in $list_of_users_to_add){
                #Optimisation = Add only user that does not already exist...
                $list_of_users +=$oneAdd
            }
		}

        #############################################
        # Restauration des users d'une base
        ##############################################
        Write-Host  -ForegroundColor Green "RESTORING DATABASE USERS : $sBaseName"
        $sQuery = FixDatabaseUsersFromList -pListOfUsersToAdd $list_of_users -pBaseName $sBaseName
	    $resQuery=Invoke-Sqlcmd -QueryTimeout 65535 -Database $sBaseName -Query $sQuery -ServerInstance $serverObject.Name
		#write-host $resQuery

}
        #############################################
        # Database Prepare (/force) de la base
        ##############################################
        Write-Host  -ForegroundColor Green "DATABASE PREPARE : $sBaseName"
        LaunchDatabasePrepare -pDatabase $sBaseName.Replace("GEN_","") -pServerURL $serverURL -pSessionId $idsession
        

        $eRestoreTime=Get-Date;
        write-host  -ForegroundColor Green ("END : Restoring Database = " + $onedbtorestore + " @ " + $eRestoreTime + "(" + ($eRestoreTime - $sRestoreTime).TotalSeconds +")" )
    }
    catch
	{
        Write-Host -ForegroundColor RED "WARNING : The following error occurs when restoring the $sBaseName Database :" $_.Exception.Message
    }
}


# EXEMPLE DE script SQL : Lance par Invoke-Sqlcmd
#[string]$sInitUserScript = "$PSScriptRoot\RecreateUser.sql"
#$resQuery=Invoke-Sqlcmd -QueryTimeout 65535 -Database $sBaseName -InputFile $sInitUserScript -ServerInstance $serverObject.Name

# EXEMPLE DE prompt :
#$result = [Microsoft.VisualBasic.Interaction]::MsgBox("You are about to restore the '$sBaseName' database on ($envCibleServer), Are you Sure ?", "YesNo,Question", "Update AWS") 
#if($result -eq "Yes"){}

#$list_of_users_to_add=@(
#	'toto@tata.com',
#	'toto@tata.com',

#)