$Log_File = "C:\Windows\Debug\BSOD_Remediation.log"
$Temp_folder = "C:\Windows\Temp"
$DMP_Logs_folder = "$Temp_folder\DMP_Logs_folder"
$DMP_Logs_folder_ZIP = "$Temp_folder\BSOD_$env:computername.zip"

$ClientID = ""
$Secret = ''	
$Site_URL = ""
$Folder_Location = ""

Function Write_Log
	{
		param(
		$Message_Type,	
		$Message
		)
		
		$MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)		
		Add-Content $Log_File  "$MyDate - $Message_Type : $Message"	
		write-host "$MyDate - $Message_Type : $Message"	
	}


Function Install_Import_Module
	{
		$Is_Nuget_Installed = $False     
		If(!(Get-PackageProvider | where {$_.Name -eq "Nuget"}))
			{                                         
				Write_Log -Message_Type "INFO" -Message "The package Nuget is not installed"                                                                          
				Try
				{
						Write_Log -Message_Type "INFO" -Message "The package Nuget is being installed"                                                                             
						[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
						Install-PackageProvider -Name Nuget -MinimumVersion 2.8.5.201 -Force -Confirm:$False | out-null                                                                                                                 
						Write_Log -Message_Type "SUCCESS" -Message "The package Nuget has been successfully installed"              
						$Is_Nuget_Installed = $True                                                                                     
					}
				Catch
					{
						Write_Log -Message_Type "ERROR" -Message "An issue occured while installing package Nuget"  
						write-output "An issue occured while installing package Nuget"  
						EXIT 1
						Break
					}
			}
		Else
			{
				$Is_Nuget_Installed = $True      
				Write_Log -Message_Type "SUCCESS" -Message "The package Nuget is already installed"                                                                                                                                         
			}

		If($Is_Nuget_Installed -eq $True)
			{
				$Script:PnP_Module_Status = $False
				$Module_Name = "PnP.PowerShell"
				If (!(Get-InstalledModule $Module_Name -ErrorAction silentlycontinue)) 				
				{ 
					Write_Log -Message_Type "INFO" -Message "The module $Module_Name has not been found"      
					Try
						{
							Write_Log -Message_Type "INFO" -Message "The module $Module_Name is being installed"                                                                                                           
							Install-Module $Module_Name -Force -Confirm:$False -ErrorAction SilentlyContinue | out-null   
							$Module_Version = (Get-Module $Module_Name -listavailable).version
							Write_Log -Message_Type "SUCCESS" -Message "The module $Module_Name has been installed"      
							Write_Log -Message_Type "INFO" -Message "$Module_Name version $Module_Version"   
							$PnP_Module_Status = $True								
						}
					Catch
						{
							Write_Log -Message_Type "ERROR" -Message "The module $Module_Name has not been installed"   
							write-output "The module $Module_Name has not been installed" 
							EXIT 1							
						}                                                                                                                                                                                                                    
				} 
				Else
				{
					Try
						{
							Write_Log -Message_Type "INFO" -Message "The module $Module_Name has been found"                                                                                                                                                                      
							Import-Module $Module_Name -Force -ErrorAction SilentlyContinue 
							$PnP_Module_Status = $True	
							Write_Log -Message_Type "INFO" -Message "The module $Module_Name has been imported"     
						}
					Catch
						{
							Write_Log -Message_Type "ERROR" -Message "The module $Module_Name has not been imported"       
							write-output "The module $Module_Name has not been imported" 
							EXIT 1								
						}                                                         
				}                                                       
			}	
	} 

Function Export_Event_Logs
	{
		param(
		$Log_To_Export,	
		$File_Name
		)	
		
		Write_Log -Message_Type "INFO" -Message "Collecting logs from: $Log_To_Export"
		Try
			{
				WEVTUtil export-log $Log_To_Export -ow:true /q:"*[System[TimeCreated[timediff(@SystemTime) <= 1296000000 ]]]" "$DMP_Logs_folder\$File_Name.evtx" | out-null
				Write_Log -Message_Type "SUCCESS" -Message "Event log $File_Name.evtx has been successfully exported"
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "An issue occured while exporting event log $File_Name.evtx"
			}
	}		

If(!(test-path $Log_File)){new-item $Log_File -type file -force | out-null}
If(test-path $DMP_Logs_folder){remove-item $DMP_Logs_folder -Force -Recurse}
new-item $DMP_Logs_folder -type Directory -force | out-null
If(test-path $DMP_Logs_folder_ZIP){Remove-Item $DMP_Logs_folder_ZIP -Force}

Write_Log -Message_Type "INFO" -Message "A recent BSOD has been found"
Write_Log -Message_Type "INFO" -Message "Date: $Last_DMP"

# Export EVTX from last 15 days
Export_Event_Logs -Log_To_Export System -File_Name "System"		
Export_Event_Logs -Log_To_Export Application -File_Name "Applications"		
Export_Event_Logs -Log_To_Export Security -File_Name "Security"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-Power/Thermal-Operational" -File_Name "KernelPower"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-PnP/Driver Watchdog" -File_Name "KernelPnP_Watchdog"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-PnP/Configuration" -File_Name "KernelPnp_Conf"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-LiveDump/Operational" -File_Name "KernelLiveDump"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-ShimEngine/Operational" -File_Name "KernelShimEngine"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-Boot/Operational" -File_Name "KernelBoot"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-IO/Operational" -File_Name "KernelIO"		


# Copy Dump files
$Minidump_Folder = "C:\Windows\Minidump"
If(test-path $Minidump_Folder){copy-item $Minidump_Folder $DMP_Logs_folder -Recurse -Force}
# If(test-path "C:\WINDOWS\MEMORY.DMP"){copy-item "C:\WINDOWS\MEMORY.DMP" $DMP_Logs_folder -Recurse -Force}

# $Get_BugCheck_Event = (Get-EventLog system -Source bugcheck -ea silentlycontinue)[0]
$Get_BugCheck_Event = (Get-EventLog system -Source bugcheck -ea silentlycontinue)
If($Get_BugCheck_Event -ne $null)
	{
		$Get_last_BugCheck_Event = $Get_BugCheck_Event[0]
		$Get_last_BugCheck_Event_Date = $Get_last_BugCheck_Event.TimeGenerated
		$Get_last_BugCheck_Event_MSG = $Get_last_BugCheck_Event.Message	
		$Get_last_BugCheck_Event_MSG | out-file "$DMP_Logs_folder\LastEvent_Message.txt"		
	}

# ZIP DMP folder
Try
	{
		Add-Type -assembly "system.io.compression.filesystem"
		[io.compression.zipfile]::CreateFromDirectory($DMP_Logs_folder, $DMP_Logs_folder_ZIP) 
		Write_Log -Message_Type "SUCCESS" -Message "The ZIP file has been successfully created"	
		Write_Log -Message_Type "INFO" -Message "The ZIP is located in :$Logs_Collect_Folder_ZIP"				
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "An issue occured while creating the ZIP file"		
		write-output "Failed step: Creating ZIP file"
		EXIT 1			
	}	
	

# Installing or importing pnp module
Install_Import_Module

Try
	{
		Connect-PnPOnline -Url $Site_URL -ClientId $ClientID -ClientSecret $Secret -WarningAction Ignore									
		Write_Log -Message_Type "SUCCESS" -Message "Connecting to SharePoint"				
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "Connecting to SharePoint"		
		write-output "Failed step: Connecting to SharePoint"
	}	

Try
	{
		Add-PnPFile -Path $DMP_Logs_folder_ZIP -Folder $Folder_Location | out-null				
		Write_Log -Message_Type "SUCCESS" -Message "Uploading file to SharePoint"	
		Disconnect-pnponline			
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "Uploading file to SharePoint"	
		write-output "Failed step: Uploading file to SharePoint"
		Disconnect-pnponline	
	}																						

Remove-Item $DMP_Logs_folder -Force -Recurse
Remove-Item $DMP_Logs_folder_ZIP -Force 