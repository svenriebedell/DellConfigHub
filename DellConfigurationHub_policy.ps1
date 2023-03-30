<#
_author_ = Sven Riebe <sven_riebe@Dell.com>
_twitter_ = @SvenRiebe
_version_ = 1.0.0
_Dev_Status_ = Test
Copyright © 2022 Dell Inc. or its subsidiaries. All Rights Reserved.

No implied support and test in test environment/device before using in any production environment.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
#>

<#Version Changes

1.0.0   inital version

Knowing Issues


#>

<#
.Synopsis
    This PowerShell will deploy settings for Dell Command | Update, Dell Optimizer, Dell Display Manager and Dell Client BIOS (WMI) to this Client. This script using a central policy file which defining which setting are assigned by administrators. 
    IMPORTANT: This script does not reboot the system to apply or query system.
    IMPORTANT: Dell Command | Update need to install first on the devices.
    IMPORTANT: Dell Optimizer need to install first on the devices.
    IMPORTANT: Dell Display Manager 2.x need to install first on the devices.

.DESCRIPTION
   PowerShell helping to maintaining settings of Dell Client Management tools by a centralized management.
#>

################################################################
###  Variables Section                                       ###
################################################################
$DellTools = @(
    [PSCustomObject]@{Name = "DCUSetting"; Enabled = $false}
    [PSCustomObject]@{Name = "BIOSPWD"; Enabled = $false}
    [PSCustomObject]@{Name = "DOSetting"; Enabled = $true}
    [PSCustomObject]@{Name = "DDM"; Enabled = $false}
    [PSCustomObject]@{Name = "BIOS"; Enabled = $false}
)

$UnuseBIOSSetting = @(
    [PSCustomObject]@{Attribute = "SysName"}
    [PSCustomObject]@{Attribute = "SysId"}
    [PSCustomObject]@{Attribute = "SvcTag"}
    [PSCustomObject]@{Attribute = "BiosVer"}
)

$TempPath = "C:\Temp\"
$Keyvault = "https://dellconfighub.blob.core.windows.net/configmaster/KeyVault.xlsx"
$DCUParameter = "/configure -importSettings="
$DCUBIOSParameter = "/configure -BIOSPassword="
$DOParameter = "/configure -importfile="
$DDMParameter = "/1:ImportSettings"

## Do not change ##
$DCUProgramName = "dcu-cli.exe"
$DCUPath = (Get-CimInstance -ClassName Win32_Product -Filter "Name like '%Dell%Command%Update%'").InstallLocation
$DCUGroup = Get-ItemPropertyValue HKLM:\SOFTWARE\Dell\DellConfigHub\DellCommandUpdate -Name UpdateGroup
$DCUConfigFile = Get-ItemPropertyValue HKLM:\SOFTWARE\Dell\DellConfigHub\DellCommandUpdate -Name UpdateFile
$DOProgramName = "do-cli.exe"
$DOPath = (Get-CimInstance -ClassName Win32_Product -Filter "Name like '%Dell Optimizer%'").InstallLocation
$DOFullName = $DOPath + $DOProgramName
$DOProgramData = Get-ItemPropertyValue HKLM:\SOFTWARE\Dell\DellOptimizer -Name DataFolderName
$DOImportPath = Get-ChildItem -path $env:ProgramData -Recurse ImportExport -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
$DOConfigFile = Get-ItemPropertyValue HKLM:\SOFTWARE\Dell\DellConfigHub\DellOptimizer -Name DOSettingFile
$BIOSConfigFile = Get-ItemPropertyValue HKLM:\SOFTWARE\Dell\DellConfigHub\BIOS -Name BIOSFile
$DDMProgramName = "ddm.exe"
$DDMPath = "C:\Program Files\Dell\Dell Display Manager 2.0\"
$DDMConfigFile = Get-ItemPropertyValue HKLM:\SOFTWARE\Dell\DellConfigHub\DellDisplayManager -Name DDMSettingFile
$DeviceName = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Name

############################################################################
# required versions for PowerShell Modules                                 #
############################################################################

[Version]$PowerShellGetVersion = "2.2.5"
[Version]$AzKeyVaultVersion = "4.7.0"
[Version]$AzAccountsVersion = "2.10.1"

################################################################
###  Functions Section                                       ###
################################################################

####################################
###  Functions Section  BIOS-PW  ###
####################################

##################################################
#### Check install missing PowerShell Modules ####
##################################################

Function find-Module
    {
    param
        (
        
        [string]$ModuleName,
        [Version]$ModuleVersion

        )
    

    ########################################
    #### Check if Module Name exist     ####
    ########################################
    
    $ModuleNameCheck = Get-InstalledModule -Name $ModuleName -ErrorAction Ignore

    If($Null -eq $ModuleNameCheck)
        {
        
        switch ($ModuleName)
            {
                Az.Accounts {'AZ'}
                Az.KeyVault {'AZ'}
                PowerShellGet {'PowerShellGet'}

            }

        Install-Module -Name $ModuleName -Force -AllowClobber

        $ModuleCheck = Get-InstalledModule -Name $ModuleName | Where-Object{$_.Version -ge "$ModuleVersion"} | Select-Object -ExpandProperty Name

        

        If($null-eq $ModuleCheck)
            {

            Write-EventLog -LogName "Dell BIOS" -EventId 40 -EntryType Error -Source "BIOS Password Manager" -Message "Error: Powershell Module $ModuleName failed to install on Device $DeviceName"

            }

        Else
            {

            Write-EventLog -LogName "Dell BIOS" -EventId 42 -EntryType SuccessAudit -Source "BIOS Password Manager" -Message "Success: Powershell Module $ModuleName is successfull installed on Device $DeviceName"

            }
        }

    
    Else
        {  
     
        $ModuleCheck = Get-InstalledModule -Name $ModuleName | Where-Object{$_.Version -ge "$ModuleVersion"} | Select-Object -ExpandProperty Name -ErrorAction Ignore

        switch ($ModuleName)
            {
                Az.Accounts {'AZ'}
                Az.KeyVault {'AZ'}
                PowerShellGet {'PowerShellGet'}

            }


        If($null-eq $ModuleCheck)
            {

            Install-Module -Name $ModuleName -Force -AllowClobber

            $ModuleCheck = Get-InstalledModule -Name $ModuleName | Where-Object{$_.Version -ge "$ModuleVersion"} | Select-Object -ExpandProperty Name

        

            If($null-eq $ModuleCheck)
                {

                Write-EventLog -LogName "Dell BIOS" -EventId 40 -EntryType Error -Source "BIOS Password Manager" -Message "Error: Powershell Module $ModuleName failed to install on Device $DeviceName"

                }

            Else
                {

                $AttributStringValue = "is installed"
                Write-EventLog -LogName "Dell BIOS" -EventId 42 -EntryType SuccessAudit -Source "BIOS Password Manager" -Message "Success: Powershell Module $ModuleName is successfull installed on Device $DeviceName"

                }

      
            }

        Else
            {

            Write-EventLog -LogName "Dell BIOS" -EventId 41 -EntryType Information -Source "BIOS Password Manager" -Message "Information: Powershell Module $ModuleName is still existing on Device $DeviceName"

            }
        }
   
    }


##################################################
#### Get KeyVault Connection Informations     ####
##################################################
function get-configdata 
    {
    param 
        (
            #[Parameter(mandatory=$true)][string]$DeviceName
        )
    
    $ExcelData = New-Object -ComObject Excel.Application
    $ReadFile = $ExcelData.workbooks.open($Keyvault,0,$true)
    ($ReadFile.ActiveSheet.UsedRange.Rows | Where-Object {$_.Columns["A"].Value2 -eq "Tenant"}).Value2
    ($ReadFile.ActiveSheet.UsedRange.Rows | Where-Object {$_.Columns["A"].Value2 -eq "ApplicationID"}).Value2
    ($ReadFile.ActiveSheet.UsedRange.Rows | Where-Object {$_.Columns["A"].Value2 -eq "Secret"}).Value2

    }


##################################################
##### Connect KeyVault                        ####
##################################################
Function Connect-KeyVaultPWD    
    {

    [SecureString]$pwd = ConvertTo-SecureString $Secret -AsPlainText -Force
    [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ($ApplicationId, $pwd)
    Connect-AzAccount -Credential $Credential -Tenant $Tenant -ServicePrincipal  

    }


####################################
#### Request BIOSPW by KeyVault ####
####################################

Function get-KeyVaultPWD
    {

    Param
        (

        [string]$KeyName 

        )

    #############################################################################
    # Check BIOS PWD for Device or PreSharedKey                                 #
    #############################################################################

    $secret = (Get-AzKeyVaultSecret -vaultName "PWDBIOS" -name $KeyName) | Select-Object *
    $Get_My_Scret = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret.SecretValue) 
    $KeyPWD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($Get_My_Scret)  
    
    Return $KeyPWD   

    }

############################
#### Password set check ####
############################

function get-AdminPWDStatus
    {

    # Check AdminPWD status 0 = no PWD is set / 1 = PWD is set
    $PWstatus = Get-CimInstance -Namespace root/dcim/sysman/wmisecurity -ClassName PasswordObject -Filter "NameId='Admin'" | Select-Object -ExpandProperty IsPasswordSet

    Switch ($PWstatus)
        {

            0 {$AttributStringValue = $false}
            1 {$AttributStringValue = $true}

        }
    
    return $AttributStringValue
    
    }


############################
#### Password encoding  ####
############################
function New-PasswordEncode
    {
    param 
        (
        
        [Parameter(mandatory=$true)][string]$AdminPw
        
        )
    
        # Encoding BIOS Password
        $Encoder = New-Object System.Text.UTF8Encoding
        $Bytes = $Encoder.GetBytes($AdminPw)
   
        Return $Bytes
   
    }


###################################
#### Convert CCTK ini to Array ####
###################################
function get-BIOSSettings 
    {

        [System.Collections.ArrayList]$BIOSCCTKData =  Get-Content "$TempPath\CCTK_Precision 7560.cctk"
        
        # Cleanup datas
        $BIOSCCTKData.Remove("[cctk]")
        $BIOSCCTKData = $BIOSCCTKData -split "="
        
 
     
        $count = $BIOSCCTKData.Count
        $BaseCount = 0
        while ($BaseCount -lt $count)        
            {
                # build a temporary array
                $BIOSArrayTemp = New-Object -TypeName psobject
                $BIOSArrayTemp | Add-Member -MemberType NoteProperty -Name 'Attribute' -Value $BIOSCCTKData[$BaseCount]
                $BIOSArrayTemp | Add-Member -MemberType NoteProperty -Name 'Value' -Value $BIOSCCTKData[$BaseCount+1]

                $BaseCount = $BaseCount +2

               [array]$BIOSSettings += $BIOSArrayTemp
            }
    return $BIOSSettings
    }

###################################
#### Clean BIOS Setting List   ####
###################################
function remove-BIOSSetting
    {
    param 
        (
       
        )

    
    foreach ($unused in $UnuseBIOSSetting)
        {

            #$BIOSConfigData | foreach ($setting in $UnuseBIOSSetting) 
                { }
                



        }
        
    }
    


###################################
#### Set BIOS Setting          ####
###################################
function set-BIOSConfig 
    {
    
        param 
            (
                
                [Parameter(mandatory=$true)][string]$SettingName,
                [Parameter(mandatory=$true)][string]$SettingValue,
                [Parameter(mandatory=$true)][string]$IsSetPWD
            )

        If($IsSetPWD -eq $true)
            {

                # set BIOS Setting by WMI with AdminPW authorization
                $BAI.SetAttribute(1,$Bytes.Length,$Bytes,$SettingName,$SettingValue)

            }
        else 
            {
            
                # set FastBoot Thorough by WMI
                $BAI.SetAttribute(0,0,0,$SettingName,$SettingValue)
            
            }     
    
    
    }


##############################################
###  Functions Section Environment Checks  ###
##############################################

#####################################
#### Check if Software installed ####
#####################################

function Get-DellApp-Installed 
    {
        param
            (
                [Parameter(mandatory=$true)][string]$DellApp
            )

    If($null -ne $DellApp)
        {

        $true

        }
    else 
        {
        
        $false

        } 
    
    }


function get-ConfigFileName 
    {
    
        param 
            (
                [Parameter(mandatory=$true)][string]$DellToolName,
                [Parameter(mandatory=$true)][string]$FilePath,
                [Parameter(mandatory=$true)][string]$FileFormat
            )

        Set-Location $FilePath 
        
        Get-ChildItem .\*.$FileFormat | Where-Object Name -Like "$DellToolName*" | Select-Object -ExpandProperty Name
        
        Set-Location \
    
    }

function get-folderstatus 
    {
    param 
        (
            [Parameter(mandatory=$true)][string]$Path
        )
    
    Test-Path $Path
    }

##############################################
###  Functions Section Dell Optimizer      ###
##############################################
function new-Optimizer-Application
    {
        param 
            (
                [Parameter(mandatory=$true)][string]$SettingName
            )
        
        [String]$CheckAppPerfomanceStatus = $DOFullName+ "/get -name=AppPerformance.State"

        $HKLMAppPath = (get-childItem -Path 'HKLM:\SOFTWARE\DELL\DellConfigHub\DellOptimizer\OptimizerSettings\Applications\').Name.Replace("HKEY_LOCAL_MACHINE","HKLM:")
        
        $Prio = 1
        foreach ($KeyPath in $HKLMAppPath)
            {

                $ProcessName = Get-ItemPropertyValue -Path $KeyPath -Name ProcessName
                $ProfileName = Get-ItemPropertyValue -Path $KeyPath -Name ProfileName

                Start-Process -FilePath $DOFullName -ArgumentList "/AppPerformance -startLearning -profileName=Edge -processName='C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe' -priority=1" -NoNewWindow -Wait

                $Prio = $Prio + 1
            }


 

            
        else 
            {
                
                Write-Host "Application.State is disabled Application Settings by Policy will be ignored" -BackgroundColor Yellow

            }
    
    
    
    
    }


################################################################
###  Program Section                                         ###
################################################################

###################################################
###  Program Section - BIOS Password            ###
###################################################

### creat log ressource
New-EventLog -LogName "Dell BIOS" -Source "BIOS Password Manager" -ErrorAction Ignore

############################################
#### Check if AdminPWD is set on device ####
############################################

$AdminPWDIsSet = get-AdminPWDStatus

if ($AdminPWDIsSet -eq $true) 
    {
        #############################################################
        #### prepare PowerShell Environment for BIOS PWD request ####
        #############################################################

        # AZ PowerShell Module
        $CheckPowerShellModule = find-Module -ModuleName PowerShellGet -ModuleVersion $PowerShellGetVersion
        # AZ PowerShell Module
        $CheckPowerShellModule = find-Module -ModuleName Az.Accounts -ModuleVersion $AzAccountsVersion
        $CheckPowerShellModule = find-Module -ModuleName Az.KeyVault -ModuleVersion $AzKeyVaultVersion

        ####################################################
        #### get connection data to connect to KeyVault ####
        ####################################################
        [Array]$KeyvaultConnection = get-configdata
        $Tenant = $KeyvaultConnection[1]
        $ApplicationId = $KeyvaultConnection[3]
        $Secret = $KeyvaultConnection[5]

        #############################
        #### Connect to KeyVault ####
        #############################
        Connect-KeyVaultPWD

        #########################################
        #### get BIOS Password from KeyVault ####
        #########################################
        $BIOSPWD = get-KeyVaultPWD -KeyName $DeviceName
        Write-Host "Get BIOS PW from KeyVault" -ForegroundColor Green

        ##################################
        #### Disconnect from KeyVault ####
        ##################################
        Disconnect-AzAccount
    }
else 
    {
        Write-Host "No AdminPWD is set on this machine" -ForegroundColor Yellow
    }

###################################################
###  Program Section - Dell Command | Update    ###
###################################################

If(($DellTools |Where-Object Name -EQ "DCUSetting" | Select-Object -ExpandProperty Enabled) -eq $true)
    {

        #### Checking if Dell Command | Update ist installed on the client system
        $CheckDCU = Get-DellApp-Installed -DellApp $DCUPath

        if($CheckDCU -eq $true)
            {
                #### Checking if download folder for xlm file is available
                $CheckTempPath = get-folderstatus -path $TempPath

                if ($CheckTempPath -ne $true) 
                    {
                        Write-Host "Folder $TempPath is not available and will generate now"
                        New-Item -Path $TempPath -ItemType Directory -Force
                        Write-Host "Folder Optimizer Import is not available and will generate now:"$TempPath
                    }
                else 
                    {
                        Write-Host "Folder $TempPath is available"
                    }

            #### Download Configuration Files to client systems
            $CheckBITS = Get-Service | Where-Object Name -EQ BITS

            If ($CheckBITS.Status -eq "Running")
                {
                    Write-Host "BITS Service is status running"
                    Start-BitsTransfer -DisplayName "Dell Command | Update Configuration File" -Source $DCUConfigFile -Destination $TempPath

                }
            else 
                {
                    Write-Host "BITS Service is disabled program stopps"
                    Write-Host "DCU Configfile can not be downloaded" 
                }
            
            ## DCU Import XML Configfile
            $DCUConfigFileName = get-ConfigFileName -DellToolName "DCU" -FilePath $TempPath -FileFormat xml
            $DCUFullName = $DCUPath + $DCUProgramName
            $DCUCLIArgument = $DCUParameter + $TempPath + $DCUConfigFileName
            $DCUImportResult = Start-Process -FilePath $DCUFullName -ArgumentList $DCUCLIArgument -NoNewWindow -Wait -PassThru

            If($DCUImportResult.ExitCode -eq 0)
                {

                    Write-Host "Dell Command | Update setting successfull imported"
                    Remove-Item $TempPath$DCUConfigFileName -Recurse -ErrorAction SilentlyContinue
                    Write-Host "temporay configfile is deleted"

                }
            else 
                {
                    Write-Host "Dell Command | Update setting import unsuccessfull."
                    Write-Host "Error Code:" $DCUImportResult.ExitCode
                }
            
            if ($AdminPWDIsSet -eq $true)
                {

                    ## DCU set BIOS PWD
                    $DCUBIOSArgument = $DCUBIOSParameter + $BIOSPWD
                    $DCUBIOSResult = Start-Process -FilePath $DCUFullName -ArgumentList $DCUBIOSArgument -Wait -PassThru

                    $DCUBIOSResult.ExitCode

                    If($DCUBIOSResult.ExitCode -eq 0)
                        {
    
                            Write-Host "Dell Command | Update BIOS setting successfull" -BackgroundColor Green
        
                        }
                    else 
                        {
                            Write-Host "Dell Command | Update BIOS setting unsuccessfull." -BackgroundColor Red
                            Write-Host "Error Code:" $DCUImportResult.ExitCode
                        }

                }
            else
                {
                
                   Write-Host "no BIOS PWD is set for Dell Command | Update" 

                }
            
            }
        else
            {

                Write-Host "No Settings are imported because Dell Command | Update is not installed"
            }

    }
else 
    {
        Write-Host "Configuration of Dell Command | Update is disabled" -ForegroundColor Red
    }


###################################################
###  Program Section - Dell Optimizer           ###
###################################################

If(($DellTools |Where-Object Name -EQ "DOSetting" | Select-Object -ExpandProperty Enabled) -eq $true)
    {

        #### Checking if Dell Optimizer is installed on the client system
        $CheckDO = Get-DellApp-Installed -DellApp $DOPath

        if($CheckDO -eq $true)
            {

                #### Checking system folder
                $CheckDOPath = get-folderstatus -Path $env:ProgramData\$DOProgramData\DellOptimizer\ImportExport
                $CheckTempPath = get-folderstatus -path $TempPath

                #### generate folder if not exist
                if ($CheckDOPath -ne $true) 
                    {
                        $TempDOPath = $env:ProgramData+"\"+$DOProgramData+"\DellOptimizer\ImportExport"
                        Write-Host "Folder Optimizer Import is not available" -BackgroundColor Yellow
                        New-Item $TempDOPath -ItemType Directory -Force
                        Write-Host "Folder Optimizer Import is not available and will generate now:"$env:ProgramData\$DOProgramData\DellOptimizer\ImportExport -BackgroundColor Green
                    }
                else 
                    {
                        Write-Host "Folder Optimizer Import"$env:ProgramData\$DOProgramData\DellOptimizer\ImportExport" is available" -BackgroundColor Green
                    }
                
                if ($CheckTempPath -ne $true) 
                    {
                        Write-Host "Folder $TempPath is not available and will generate now" -BackgroundColor Yellow
                        New-Item $TempPath -ItemType Directory -Force

                    }
                else 
                    {
                        Write-Host "Folder $TempPath is available" -BackgroundColor Green
                    }
          
                #### Download Configuration Files to client systems
                $CheckBITS = Get-Service | Where-Object Name -EQ BITS

                If ($CheckBITS.Status -eq "Running")
                    {
                        Write-Host "BITS Service is status running" -BackgroundColor Green
                        Start-BitsTransfer -DisplayName "Dell Optimizer" -Source $DOConfigFile -Destination $DOImportPath
                    }
                else 
                    {
                        Write-Host "BITS Service is disabled program stopps" -BackgroundColor Yellow
                        Write-Host "DCU Configfile can not be downloaded" -BackgroundColor Red
                    }


                ## DO Import
                $DOConfigFileName = get-ConfigFileName -DellToolName "DO" -FilePath $DOImportPath -FileFormat json
                $DOCLIArgument = $DOParameter + $DOConfigFileName
                $DOImportResult = Start-Process -FilePath $DOFullName -ArgumentList $DOCLIArgument -NoNewWindow -Wait -PassThru

                $DOImportResult.ExitCode

                If($DOImportResult.ExitCode -eq 0)
                    {
                        Write-Host "Dell Optimizer setting imported successfull" -BackgroundColor Green
                    }
                else 
                    {
                        Write-Host "Dell Optimizer setting import is unsuccessfull." -BackgroundColor Red
                        Write-Host "Error Code:" $DOImportResult.ExitCode
                    }

            }
        else
            {
                Write-Host "No Settings are imported because Dell Optimizer is not installed" -BackgroundColor Yellow
            }
    }
else 
    {
        Write-Host "Configuration of Dell Optimizer is disabled" -ForegroundColor Red
    }


###################################################
###  Program Section - BIOS Settings            ###
###################################################

If(($DellTools |Where-Object Name -EQ "BIOS" | Select-Object -ExpandProperty Enabled) -eq $true)
    {
        #### Checking if download folder for ini file is available
        $CheckTempPath = get-folderstatus -path $TempPath

        if ($CheckTempPath -ne $true) 
            {
                Write-Host "Folder $TempPath is not available and will generate now"
                New-Item -Path $TempPath -ItemType Directory -Force
                Write-Host "Folder Optimizer Import is not available and will generate now:"$TempPath
            }
        else 
            {
                Write-Host "Folder $TempPath is available" -ForegroundColor Green
            }
        
        #### Download Configuration Files to client systems
        $CheckBITS = Get-Service | Where-Object Name -EQ BITS

        If ($CheckBITS.Status -eq "Running")
            {
                Write-Host "BITS Service is status running" -ForegroundColor Green
                Start-BitsTransfer -DisplayName "Dell BIOS Configuration File" -Source $BIOSConfigFile -Destination $TempPath
            }
        else 
            {
                Write-Host "BITS Service is disabled program stopps" -ForegroundColor Red
                Write-Host "BIOS Configfile can not be downloaded" 
            }

        [System.Collections.ArrayList]$BIOSConfigData = get-BIOSSettings

        #Connect to the BIOSAttributeInterface WMI class
        $BAI = Get-WmiObject -Namespace root/dcim/sysman/biosattributes -Class BIOSAttributeInterface

        $AdminPWDIsSet = get-AdminPWDStatus

        if ($AdminPWDIsSet -eq $true)
            {

                # Encoding BIOS Password
                $Encoder = New-Object System.Text.UTF8Encoding
                $Bytes = $Encoder.GetBytes($BIOSPWD)

                foreach ($BIOS in $BIOSConfigData)
                    {

                        # set BIOS Setting by WMI with AdminPW authorization
                        $BIOSSettingResult = $BAI.SetAttribute(1,$Bytes.Length,$Bytes,$BIOS.attribute,$BIOS.Value)

                        If ($BIOSSettingResult.status -eq 0)
                            {
                               Write-Host "BIOS Setting $bios.Name is set successful" -ForegroundColor Green
                            }
                        else 
                            {
                                Write-Host "BIOS Setting $bios.Name is set unsuccessful" -ForegroundColor Red
                                Write-Host "Error Code:"$BIOSSettingResult.status
                            }

                    }
            }
        else 
            {
                foreach ($BIOS in $BIOSConfigData)
                    {
                        # set BIOS Setting by WMI with AdminPW authorization
                        $BIOSSettingResult = $BAI.SetAttribute(0,0,0,$BIOS.Name,$BIOS.Value)

                        If ($BIOSSettingResult.status -eq 0)
                            {
                                Write-Host "BIOS Setting $bios.Name is set successful"
                            }
                        else 
                            {
                                Write-Host "BIOS Setting $bios.Name is set unsuccessful" -ForegroundColor Red -BackgroundColor Gray
                                Write-Host "Error Code:"$BIOSSettingResult.status
                            }
                    }
            }
                    
    }
else 
    {
        Write-Host "Configuration of Dell BIOS is disabled" -ForegroundColor Red
    }


###################################################
###  Program Section - Dell Display Manager 2   ###
###################################################

If(($DellTools |Where-Object Name -EQ "DDM" | Select-Object -ExpandProperty Enabled) -eq $true)
    {
        #### Checking if Dell Dell Display Manager is installed on the client system
        $CheckDDM= Get-DellApp-Installed -DellApp $DDMPath

        if($CheckDDM -eq $true)
            {
                #### Checking if download folder for JSON file is available
                $CheckTempPath = get-folderstatus -path $TempPath

                if ($CheckTempPath -ne $true) 
                    {
                        Write-Host "Folder $TempPath is not available and will generate now"
                        New-Item -Path $TempPath -ItemType Directory -Force
                    }
                else 
                    {
                        Write-Host "Folder $TempPath is available"
                    }

                #### Download Configuration File to client systems
                $CheckBITS = Get-Service | Where-Object Name -EQ BITS

                If ($CheckBITS.Status -eq "Running")
                    {
                        Write-Host "BITS Service is status running" -ForegroundColor Green
                        Start-BitsTransfer -DisplayName "Dell Display Manager 2.x" -Source $DDMConfigFile -Destination $TempPath

                    }
                else 
                    {
                        Write-Host "BITS Service is disabled program stopps"
                        Write-Host "DCU Configfile can not be downloaded" 
                    }
                
                ## DDM Import JSON Configfile
                $DDMConfigFileName = get-ConfigFileName -DellToolName "DDM" -FilePath $TempPath -FileFormat JSON
                $DDMFullName = $DDMPath + $DDMProgramName
                $DDMCLIArgument = $DDMParameter + $TempPath + $DDMConfigFileName
                $DDMImportResult = Start-Process -FilePath $DDMFullName -ArgumentList $DDMCLIArgument -NoNewWindow -Wait -PassThru

                If($DDMImportResult.ExitCode -eq 0)
                    {
                        Write-Host "Dell Display Manager setting successfull imported"
                        Remove-Item $TempPath$DDMConfigFileName -Recurse -ErrorAction SilentlyContinue
                        Write-Host "temporay configfile is deleted"
                    }
                else 
                    {
                        Write-Host "Dell Display Manager setting import unsuccessfull."
                        Write-Host "Error Code:" $DDMImportResult.ExitCode
                    }
            }
    }
else 
    {
        Write-Host "Configuration of Dell Display Manager is disabled" -ForegroundColor Red
    }