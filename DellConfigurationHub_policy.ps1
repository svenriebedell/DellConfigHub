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

Write-Host "Start of Program"

################################################################
###  Variables Section                                       ###
################################################################
$DellTools = @(
    [PSCustomObject]@{Name = "DCUSetting"; Enabled = $true} # incl. Import XML File and set BIOS PWD is enabled and available by KeyVault
    [PSCustomObject]@{Name = "DOSetting"; Enabled = $true}
    [PSCustomObject]@{Name = "DOAppLearning"; Enabled = $true}
    [PSCustomObject]@{Name = "DDM"; Enabled = $true}
    [PSCustomObject]@{Name = "BIOS"; Enabled = $true}
)

$UnuseBIOSSetting = @(
    [PSCustomObject]@{Attribute = "SysName"}
    [PSCustomObject]@{Attribute = "SysId"}
    [PSCustomObject]@{Attribute = "SvcTag"}
    [PSCustomObject]@{Attribute = "BiosVer"}
    [PSCustomObject]@{Attribute = "Advsm"}
    [PSCustomObject]@{Attribute = ";ChassisIntruStatus"}
    [PSCustomObject]@{Attribute = "BootOrder"}
    
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
$DOProgramName = "do-cli.exe"
$DOPath = (Get-CimInstance -ClassName Win32_Product -Filter "Name like '%Dell Optimizer%'").InstallLocation
$DOFullName = $DOPath + $DOProgramName
$DOImportPath = Get-ChildItem -path $env:ProgramData -Recurse ImportExport -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
$DDMProgramName = "ddm.exe"
$DDMPath = "C:\Program Files\Dell\Dell Display Manager 2\"
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

Function find-AZModule
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
    $AZConnect = Connect-AzAccount -Credential $Credential -Tenant $Tenant -ServicePrincipal  

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
        param 
        (
        
        [Parameter(mandatory=$true)][string]$CCTKFileName
        
        )

        [System.Collections.ArrayList]$BIOSCCTKData =  Get-Content "$TempPath\$CCTKFileName"
        
        # Cleanup datas
        $BIOSCCTKData.Remove("[cctk]")
        $BIOSCCTKData = $BIOSCCTKData -split "="
                 
     
        $count = $BIOSCCTKData.Count
        $BaseCount = 0
        while ($BaseCount -lt $count)        
            {
                # check and igonre if Attribute part of $UnuseBIOSSetting
                if(($UnuseBIOSSetting.Attribute.Contains($BIOSCCTKData[$BaseCount])) -ne $true)
                    {
                        # correction PasswordConfiguration setting for array
                        If(($BIOSCCTKData[$BaseCount]) -eq "PasswordConfiguration")
                            {
                                # Split Value to Attribute and Value by ":"
                                $PWDSettings = ""
                                $PWDSettings = $BIOSCCTKData[$BaseCount+1].Split(":")

                                # build a temporary array if setting not included by $UnuseBIOSSetting
                                $BIOSArrayTemp = New-Object -TypeName psobject
                                $BIOSArrayTemp | Add-Member -MemberType NoteProperty -Name 'Attribute' -Value $PWDSettings[0]
                                $BIOSArrayTemp | Add-Member -MemberType NoteProperty -Name 'Value' -Value $PWDSettings[1]

                                $BaseCount = $BaseCount +2

                            }
                        else 
                            {
                                # build a temporary array if setting not included by $UnuseBIOSSetting
                                $BIOSArrayTemp = New-Object -TypeName psobject
                                $BIOSArrayTemp | Add-Member -MemberType NoteProperty -Name 'Attribute' -Value $BIOSCCTKData[$BaseCount]
                                $BIOSArrayTemp | Add-Member -MemberType NoteProperty -Name 'Value' -Value $BIOSCCTKData[$BaseCount+1]

                                $BaseCount = $BaseCount +2
                            }

                        [array]$BIOSSettings += $BIOSArrayTemp
                    }
                else 
                    {

                        Write-Host "Information: Bios setting" $BIOSCCTKData[$BaseCount] "is incl. on Var UnuseBIOSSetting and not used for the config array" -BackgroundColor Yellow
                        $BaseCount = $BaseCount +2
                    }

                
            }
    return $BIOSSettings
    }


###################################
#### Set BIOS Setting          ####
###################################
function set-BIOSConfig 
    {
    
        param 
            (
                
                [Parameter(mandatory=$true)][string]$SettingName,
                [Parameter(mandatory=$false)][string]$SettingValue,
                [Parameter(mandatory=$true)][string]$IsSetPWD
            )

        
        $WMIClass = $null
        $SettingStatus = $null
        
        If(($BIOSEnumeration.AttributeName.Contains("$SettingName")) -eq $true)
            {

                Write-Host "Information: Setting $SettingName in WMI Class EnumerationAttribute"
                $WMIClass = "EnumerationAttribute"
                $ValueCurrent = $BIOSEnumeration | Where-Object AttributeName -EQ $SettingName | Select-Object -ExpandProperty CurrentValue
                
                If ($ValueCurrent -eq $SettingValue)
                    {

                        Write-Host "Information: $Settingname has same value as CurrentValue" -foregroundColor Yellow
                        $SettingStatus = $false

                    }
                else 
                    {
                        
                        Write-Host "Information: $Settingname has not same value as CurrentValue" -ForegroundColor Red
                        $SettingStatus = $true
                       
                    }

            }
        If(($BIOSInteger.AttributeName.Contains("$SettingName")) -eq $true)
            {

                Write-Host "Information: Setting $SettingName in WMI Class IntegerAttribute"
                $WMIClass = "IntegerAttribute"
                $ValueCurrent = $BIOSInteger | Where-Object AttributeName -EQ $SettingName | Select-Object -ExpandProperty CurrentValue

                If ($ValueCurrent -eq $SettingValue)
                    {

                        Write-Host "Information: $Settingname has same value as CurrentValue" -foregroundColor Yellow
                        $SettingStatus = $false

                    }
                else 
                    {
                        
                        Write-Host "Information: $Settingname has not same value as CurrentValue" -ForegroundColor Red
                        $SettingStatus = $true
                       
                    }

            }
        If(($BIOSString.AttributeName.Contains("$SettingName")) -eq $true)
            {

                Write-Host "Information: Setting $SettingName in WMI Class StringAttribute"
                $WMIClass = "StringAttribute"
                $ValueCurrent = $BIOSString | Where-Object AttributeName -EQ $SettingName | Select-Object -ExpandProperty CurrentValue

                If ($ValueCurrent -eq $SettingValue)
                    {

                        Write-Host "Information: $Settingname has same value as CurrentValue" -foregroundColor Yellow
                        $SettingStatus = $false

                    }
                else
                    {
                        
                        Write-Host "Information: $Settingname has not same value as CurrentValue" -ForegroundColor Red
                        $SettingStatus = $true
                       
                    }

            }
        If($null -eq $WMIClass)
            {

                Write-Host "$SettingName have no WMI Class" -BackgroundColor Yellow


            }

        If($SettingStatus -eq $true)
            {

                if ($IsSetPWD -eq $true)
                    {

                        # Encoding BIOS Password
                        $Encoder = New-Object System.Text.UTF8Encoding
                        $Bytes = $Encoder.GetBytes($BIOSPWD)

                        # set BIOS Setting by WMI with AdminPW authorization
                        $BIOSSettingResult = $BIOSInterface.SetAttribute(1,$Bytes.Length,$Bytes,$SettingName,$SettingValue)
                        $BIOSSettingCode = $BIOSSettingResult

                        switch ($BIOSSettingCode) 
                            {
                                0       {"0 - Success"}
                                1       {"1 - Failed"}
                                2       {"2 - Invalid Parameter"}
                                3       {"3 - Access Denied"}
                                4       {"4 - Not Supported"}
                                5       {"5 - Memory Error"}
                                6       {"6 - Protocol Error"}

                            }
                            

                        If ($BIOSSettingResult.status -eq 0)
                            {
                                Write-Host "Success: BIOS Setting $SettingName is set successful" -BackgroundColor Green
                            }
                        else 
                            {
                                Write-Host "Error: BIOS Setting $SettingName is set unsuccessful" -BackgroundColor Red
                                Write-Host "Error Code:"$BIOSSettingCode
                            }

            
                    }
                else 
                    {

                        # set BIOS Setting by WMI with AdminPW authorization
                        $BIOSSettingResult = $BIOSInterface.SetAttribute(0,0,0,$SettingName,$SettingValue)
                        $BIOSSettingCode = $BIOSSettingResult

                        switch ($BIOSSettingCode) 
                            {
                                0       {"0 - Success"}
                                1       {"1 - Failed"}
                                2       {"2 - Invalid Parameter"}
                                3       {"3 - Access Denied"}
                                4       {"4 - Not Supported"}
                                5       {"5 - Memory Error"}
                                6       {"6 - Protocol Error"}

                            }
                            

                        If ($BIOSSettingResult.status -eq 0)
                            {
                                Write-Host "Success: BIOS Setting $SettingName is set successful" -BackgroundColor Green
                            }
                        else 
                            {
                                Write-Host "Error: BIOS Setting $SettingName is set unsuccessful" -BackgroundColor Red
                                Write-Host "Error Code:"$BIOSSettingCode
                            }
            
                    }

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

#####################################
#### Get the required Filename   ####
#####################################
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

#####################################
#### Check if folder exist       ####
#####################################
function get-folderstatus 
    {
    param 
        (
            [Parameter(mandatory=$true)][string]$Path
        )
    
    Test-Path $Path
    }

#####################################
#### Check if policy setting exist ##
#####################################
function get-Policystatus 
    {
    param 
        (
            [Parameter(mandatory=$true)][string]$RegPath,
            [Parameter(mandatory=$true)][string]$RegValue
        )
    
        try 
            {
                $CheckHKLMPath = Test-Path -Path $RegPath

                if($CheckHKLMPath -eq $true)
                    {

                        Get-ItemPropertyValue $RegPath -Name $RegValue

                    }
                else 
                    {
                        Return $false
                    }

                

            }
        catch 
            
            {
                Return $false
            }

    }

#####################################
### Change enable status $DellTools #
#####################################

function set-Enablestatus 
    {
        param 
            (
                [Parameter(mandatory=$true)][string]$ToolName,
                [Parameter(mandatory=$true)][string]$ToolEnabled
            )
        
        
            if (($DellTools | Where-Object name -EQ $ToolName | Select-Object -ExpandProperty Enabled) -eq $true)
                {

                    If($ToolEnabled -ne $false)
                        {

                            Write-Host "Information: $ToolName is enabled and policy found" -BackgroundColor Green

                        }
                    else 
                        {
                            
                            Write-Host "Error: $ToolName is enabled no policy found. Setting deployment will disabled" -BackgroundColor Red
                            ($DellTools | Where-Object name -EQ $ToolName).Enabled = $false
                        }


                }
    
    
    
    }


##############################################
###  Functions Section Dell Optimizer      ###
##############################################
function Get-Optimizer-Application
    {
   
        $HKLMAppPath = (get-childItem -Path 'HKLM:\SOFTWARE\DELL\DellConfigHub\DellOptimizer\OptimizerSettings\Applications\').Name.Replace("HKEY_LOCAL_MACHINE","HKLM:")
        
        $Prio = 1
        foreach ($KeyPath in $HKLMAppPath)
            {

                $ProcessName = Get-ItemPropertyValue -Path $KeyPath -Name ProcessName
                $ProfileName = Get-ItemPropertyValue -Path $KeyPath -Name ProfileName

                If(("" -ne $ProfileName) -and ("" -ne $ProcessName))
                    {

                        Write-Host "Profile $ProfileName with $ProcessName is starting to learning mode"
                        Set-Location -Path $DOPath
                        $CheckResult = .\do-cli.exe /AppPerformance -startLearning -profileName="$ProfileName" -processName="$ProcessName" -priority=1
                        Set-Location -Path C:\

                        If($CheckResult -eq $true)
                            {

                                Write-Host "Success: Profile $ProfileName set successfully" -BackgroundColor Green

                            }
                        else 
                            {
                                
                                Write-Host "Information: Process $ProcessName is existing on device" -BackgroundColor Yellow

                            }

                    }
                else 
                    {
                        Write-Host "Information: $KeyPath has no values check policy or registry if you missing applications for learning mode" -BackgroundColor Yellow
                    }


                $Prio = $Prio + 1
            }
        
    }

function Get-StatusOptimizerSetting
    {
        param 
            (
                [Parameter(mandatory=$true)][string]$SettingName
            )
        
        Set-Location -Path $DOPath
        .\do-cli.exe /get -name="$SettingName"
        Set-Location c:\
    
    }


################################################################
###  Program Section                                         ###
################################################################


###################################################
###  Program Section - Get ADMX informations    ###
###################################################

$DCUConfigFile = get-Policystatus -RegPath HKLM:\SOFTWARE\Dell\DellConfigHub\DellCommandUpdate -RegValue UpdateFile
$DOProgramData = get-Policystatus -RegPath HKLM:\SOFTWARE\Dell\DellOptimizer -RegValue DataFolderName
$DOConfigFile = get-Policystatus -RegPath HKLM:\SOFTWARE\Dell\DellConfigHub\DellOptimizer -RegValue DOSettingFile
$DOAppSettings = get-Policystatus -RegPath HKLM:\SOFTWARE\DELL\DellConfigHub\DellOptimizer\OptimizerSettings\Applications\App1 -RegValue ProcessName #check if you set App1 first by ADMX
$BIOSConfigFile = get-Policystatus -RegPath HKLM:\SOFTWARE\Dell\DellConfigHub\BIOS -RegValue BIOSFile
$DDMConfigFile = get-Policystatus -RegPath HKLM:\SOFTWARE\Dell\DellConfigHub\DellDisplayManager -RegValue DDMSettingFile

## Change enabled status to false if no policy is availible
set-Enablestatus -ToolName DCUSetting -ToolEnabled $DCUConfigFile
set-Enablestatus -ToolName DOSetting  -ToolEnabled $DOConfigFile
set-Enablestatus -ToolName DOAppLearning -ToolEnabled $DOAppSettings
set-Enablestatus -ToolName DDM -ToolEnabled $DDMConfigFile
set-Enablestatus -ToolName BIOS -ToolEnabled $BIOSConfigFile

###################################################
###  Program Section - BIOS Password            ###
###################################################

### starting this section only if Dell Command | Update or BIOS Settings are enabled.

If((($DellTools |Where-Object Name -EQ "DCUSetting" | Select-Object -ExpandProperty Enabled) -eq $true) -or (($DellTools |Where-Object Name -EQ "BIOS" | Select-Object -ExpandProperty Enabled) -eq $true))
    {
        Write-Host "************************************************************************"
        Write-Host "********* Start BIOS Password Section with Microsoft KeyVault **********"
        ### creat log ressource
        New-EventLog -LogName "Dell BIOS" -Source "BIOS ConfigHub" -ErrorAction Ignore

        ############################################
        #### Check if AdminPWD is set on device ####
        ############################################

        $AdminPWDIsSet = get-AdminPWDStatus

        if ($AdminPWDIsSet -eq $true) 
            {

                Write-Host "BIOS Password is set on device starting now get datas from KeyVault" -ForegroundColor Green
                #############################################################
                #### prepare PowerShell Environment for BIOS PWD request ####
                #############################################################

                # AZ PowerShell Module
                $CheckPowerShellModule = find-AZModule -ModuleName PowerShellGet -ModuleVersion $PowerShellGetVersion
                $CheckPowerShellModule = find-AZModule -ModuleName Az.Accounts -ModuleVersion $AzAccountsVersion
                $CheckPowerShellModule = find-AZModule -ModuleName Az.KeyVault -ModuleVersion $AzKeyVaultVersion

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

                #checking if BIOS PWD was available for device
                If ($null -ne $BIOSPWD)
                    {

                        Write-Host "BIOS Password is found" -BackgroundColor Green

                    }
                else 
                    {

                        Write-Host "BIOS Password is not found" -BackgroundColor Red
                        Write-Host "BIOS Settings and DCU Set BIOS Password will not working" -ForegroundColor Red

                    }

                Write-Host "Get BIOS PW from KeyVault" -ForegroundColor Green

                ##################################
                #### Disconnect from KeyVault ####
                ##################################
                $AZDisconnect = Disconnect-AzAccount
            }
        else 
            {
                Write-Host "No AdminPWD is set on this machine" -ForegroundColor Yellow
            }
    

        Write-Host "********** End BIOS Password Section with Microsoft KeyVault ***********"
        Write-Host "************************************************************************"
    }
else 
    {
        Write-Host "Information: No BIOS Password is needed for selected configuration options" -ForegroundColor Yellow
    }



###################################################
###  Program Section - Dell Command | Update    ###
###################################################

If(($DellTools |Where-Object Name -EQ "DCUSetting" | Select-Object -ExpandProperty Enabled) -eq $true)
    {
        Write-Host "************************************************************************"
        Write-Host "******* Start of section Dell Command | Update import config XML *******"
        #### Checking if Dell Command | Update ist installed on the client system
        $CheckDCU = Get-DellApp-Installed -DellApp $DCUPath

        if($CheckDCU -eq $true)
            {
                #### Checking if download folder for xlm file is available
                $CheckTempPath = get-folderstatus -path $TempPath

                if ($CheckTempPath -ne $true) 
                    {
                        Write-Host "Folder $TempPath is not available and will generate now" -BackgroundColor Yellow
                        New-Item -Path $TempPath -ItemType Directory -Force
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
                    Write-Host "Download Dell Command | Update XML "$DCUConfigFile
                    Start-BitsTransfer -DisplayName "Dell Command | Update Configuration File" -Source $DCUConfigFile -Destination $TempPath

                }
            else 
                {
                    Write-Host "BITS Service is disabled program stopps" -BackgroundColor Red
                    Write-Host "DCU Configfile can not be downloaded" -BackgroundColor Red
                }
            
            ## DCU Import XML Configfile
            $DCUConfigFileName = get-ConfigFileName -DellToolName "DCU" -FilePath $TempPath -FileFormat xml
            $DCUFullName = $DCUPath + $DCUProgramName
            $DCUCLIArgument = $DCUParameter + $TempPath + $DCUConfigFileName
            $DCUImportResult = Start-Process -FilePath $DCUFullName -ArgumentList $DCUCLIArgument -NoNewWindow -Wait -PassThru

            If($DCUImportResult.ExitCode -eq 0)
                {
                    Write-Host ""
                    Write-Host "Dell Command | Update setting successfull imported" -BackgroundColor Green
                    Remove-Item $TempPath$DCUConfigFileName -Recurse -ErrorAction SilentlyContinue
                    Write-Host "temporay configfile is deleted"

                }
            else 
                {
                    Write-Host "Dell Command | Update setting import unsuccessfull." -BackgroundColor Red
                    Write-Host "Error Code:" $DCUImportResult.ExitCode
                }
            
            Write-Host "******* End of section Dell Command | Update import config XML *******"
            Write-Host "**********************************************************************"
            Write-Host ""
            
            if ($AdminPWDIsSet -eq $true)
                {
                    Write-Host "************************************************************************"
                    Write-Host "***** Start of section BIOS Password setting Dell Command | Update *****"
                    ## DCU set BIOS PWD
                    $DCUBIOSArgument = $DCUBIOSParameter + $BIOSPWD
                    $DCUBIOSResult = Start-Process -FilePath $DCUFullName -ArgumentList $DCUBIOSArgument -Wait -PassThru -NoNewWindow
                    
                    If($DCUBIOSResult.ExitCode -eq 0)
                        {
                            Write-Host ""
                            Write-Host "Dell Command | Update set BIOS Password successfully" -BackgroundColor Green
                            Write-Host "***** End of section BIOS Password setting Dell Command | Update *****"
                            Write-Host "**********************************************************************"
                            Write-Host ""
        
                        }
                    else 
                        {
                            Write-Host "Dell Command | Update set BIOS Password unsuccessfully." -BackgroundColor Red
                            Write-Host "Error Code:" $DCUImportResult.ExitCode
                            Write-Host "***** End of section BIOS Password setting Dell Command | Update *****"
                            Write-Host "****************************************************************"
                            Write-Host ""
                        }

                }
            else
                {
                    Write-Host "************************************************************************"
                    Write-Host "***** Start of section BIOS Password setting Dell Command | Update *****"
                    Write-Host "This device have no BIOS Password" 

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
        
        Write-Host "************************************************************************"
        Write-Host "********** Start of section Dell Optimizer import config JSON **********"
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
                        Write-Host "Download Dell Optimizer JSON "$DOConfigFile
                        Start-BitsTransfer -DisplayName "Dell Optimizer" -Source $DOConfigFile -Destination $DOImportPath
                    }
                else 
                    {
                        Write-Host "BITS Service is disabled program stopps" -BackgroundColor Yellow
                        Write-Host "Dell Optimizer Configfile can not be downloaded" -BackgroundColor Red
                    }


                ## DO Import
                $DOConfigFileName = get-ConfigFileName -DellToolName "DO" -FilePath $DOImportPath -FileFormat json
                $DOCLIArgument = $DOParameter + $DOConfigFileName
                $DOImportResult = Start-Process -FilePath $DOFullName -ArgumentList $DOCLIArgument -NoNewWindow -Wait -PassThru

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

        Write-Host "*********** End of section Dell Optimizer import config JSON ***********"
        Write-Host "************************************************************************"
        Write-Host ""
        
    }
else 
    {
        Write-Host "Configuration of Dell Optimizer is disabled" -ForegroundColor Red
    }

If(($DellTools |Where-Object Name -EQ "DOAppLearning" | Select-Object -ExpandProperty Enabled) -eq $true)
    {
        Write-Host "************************************************************************"
        Write-Host "********* Start of section Dell Optimizer Application learning *********"
        ### Application Learning ###
        $CheckDO = Get-DellApp-Installed -DellApp $DOPath

        if($CheckDO -eq $true)
            {

                $AppPerformenceStatus = Get-StatusOptimizerSetting -SettingName AppPerformance.State

                If((($AppPerformenceStatus | Select-String "Value:").Line.Contains("True")) -eq $true)
                    {
                        Write-Host "AppPerformance.State is enabled" -ForegroundColor Green
                        Get-Optimizer-Application
                    }
                else
                    {
                        Write-Host "Error: AppPerformance.State is not enabled" -ForegroundColor Red
                        Write-Host "Application learning not used, please check your Optimizer Configuration file" -ForegroundColor Red
                    }
            }
        else
            {
                Write-Host "Information: No Applications learned because Dell Optimizer is not installed" -BackgroundColor Yellow
            }
        Write-Host "********** End of section Dell Optimizer Application learning **********"
        Write-Host "************************************************************************"
        Write-Host ""
    }
else 
    {
        Write-Host "Application learning of Dell Optimizer is disabled" -ForegroundColor Red
    }

###################################################
###  Program Section - BIOS Settings            ###
###################################################

# Connect to the BIOSAttributeInterface WMI class
$BIOSInterface = Get-WmiObject -Namespace root/dcim/sysman/biosattributes -Class BIOSAttributeInterface
#Connect to the EnumerationAttribute WMI class
$BIOSEnumeration = Get-CimInstance -Namespace root\dcim\sysman\biosattributes -ClassName EnumerationAttribute
#Connect to the IntegerAttribute WMI class
$BIOSInteger = Get-CimInstance -Namespace root\dcim\sysman\biosattributes -ClassName IntegerAttribute
#Connect to the StringAttribute WMI class
$BIOSString = Get-CimInstance -Namespace root\dcim\sysman\biosattributes -ClassName StringAttribute

If(($DellTools |Where-Object Name -EQ "BIOS" | Select-Object -ExpandProperty Enabled) -eq $true)
    {
        #### Checking if download folder for ini file is available
        $CheckTempPath = get-folderstatus -path $TempPath

        if ($CheckTempPath -ne $true) 
            {
                Write-Host "Folder $TempPath is not available and will generate now"
                New-Item -Path $TempPath -ItemType Directory -Force

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
                Write-Host "Download Dell BIOS Setting CCTK "$BIOSConfigFile
                Start-BitsTransfer -DisplayName "Dell BIOS Configuration File" -Source $BIOSConfigFile -Destination $TempPath
            }
        else 
            {
                Write-Host "BITS Service is disabled program stopps" -ForegroundColor Red
                Write-Host "BIOS Configfile can not be downloaded" 
            }

        $CCTKConfigFileName = get-ConfigFileName -DellToolName "CCTK" -FilePath $TempPath -FileFormat cctk
        [System.Collections.ArrayList]$BIOSConfigData = get-BIOSSettings -CCTKFileName $CCTKConfigFileName
        
        # Checking if BIOS Admin PWd is set on device and set BIOS Setting with BIOS PWD if needed
        $AdminPWDIsSet = get-AdminPWDStatus

        # Checken and change BIOS Setting
        foreach ($BIOS in $BIOSConfigData)
            {

                set-BIOSConfig -SettingName $Bios.Attribute -SettingValue $Bios.value -IsSetPWD $AdminPWDIsSet
                               
            }
        
        Remove-Item $TempPath$DDMConfigFileName -Recurse -ErrorAction SilentlyContinue
            Write-Host "temporay configfile is deleted"
                    
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
        Write-Host "************************************************************************"
        Write-Host "****** Start of section Dell Display Manager 2 import config JSON ******"

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
                        Write-Host "Download Dell Disply Manager 2 JSON "$DDMConfigFile
                        Start-BitsTransfer -DisplayName "Dell Display Manager 2.x" -Source $DDMConfigFile -Destination $TempPath
                        Write-Host ""

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
                        Write-Host "Dell Display Manager setting successfull imported" -BackgroundColor Green
                        Remove-Item $TempPath$DDMConfigFileName -Recurse -ErrorAction SilentlyContinue
                        Write-Host "temporay configfile is deleted"
                    }
                else 
                    {
                        Write-Host "Dell Display Manager setting import unsuccessfull." -BackgroundColor Red
                        Write-Host "Error Code:" $DDMImportResult.ExitCode
                    }
            }
        
        Write-Host "****** Start of section Dell Display Manager 2 import config JSON ******"
        Write-Host "************************************************************************"
        Write-Host ""
    }
else 
    {
        Write-Host "Configuration of Dell Display Manager is disabled" -ForegroundColor Red
    }


Write-Host "End of Program"