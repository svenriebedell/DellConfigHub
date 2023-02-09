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
    [PSCustomObject]@{Name = "DCUSetting"; Enabled = $true}
    [PSCustomObject]@{Name = "BIOSPWD"; Enabled = $true}
    [PSCustomObject]@{Name = "DOSetting"; Enabled = $true}
    [PSCustomObject]@{Name = "DDM"; Enabled = $false}
    [PSCustomObject]@{Name = "BIOS"; Enabled = $true}
)

$TempPath = "C:\Temp\"
$Keyvault = "https://dellconfighub.blob.core.windows.net/configmaster/KeyVault.xlsx"
$DCUParameter = "/configure -importSettings="
$DCUBIOSParameter = "/configure -BIOSPassword="
$DOParameter = "/configure -importfile="


## Do not change ##
$DCUProgramName = "dcu-cli.exe"
$DCUPath = (Get-CimInstance -ClassName Win32_Product -Filter "Name like '%Dell%Command%Update%'").InstallLocation
$DCUGroup = Get-ItemPropertyValue HKLM:\SOFTWARE\Dell\DellConfigHub\DellCommandUpdate -Name UpdateGroup
$DCUConfigFile = Get-ItemPropertyValue HKLM:\SOFTWARE\Dell\DellConfigHub\DellCommandUpdate -Name UpdateFile
$DOProgramName = "do-cli.exe"
$DOPath = (Get-CimInstance -ClassName Win32_Product -Filter "Name like '%Dell Optimizer%'").InstallLocation
$DOProgramData = Get-ItemPropertyValue HKLM:\SOFTWARE\Dell\DellOptimizer -Name DataFolderName
$DOImportPath = Get-ChildItem -path $env:ProgramData -Recurse ImportExport -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
$DOConfigFile = Get-ItemPropertyValue HKLM:\SOFTWARE\Dell\DellConfigHub\DellOptimizer -Name DOSettingFile
$BIOSConfigFile = Get-ItemPropertyValue HKLM:\SOFTWARE\Dell\DellConfigHub\BIOS -Name BIOSFile
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

##################################################
#### Check install missing PowerShell Modules ####
##################################################

Function Check-Module
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


##################################
#### Connect to KeyVault      ####
##################################

Function Connect-KeyVaultPWD
    {

    #############################################################################
    # Connect KeyVault                                                          #
    #############################################################################

    [SecureString]$pwd = ConvertTo-SecureString $Secret -AsPlainText -Force
    [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ($ApplicationId, $pwd)
    Connect-AzAccount -Credential $Credential -Tenant $Tenant -ServicePrincipal  

    }


##################################
#### Request KeyVault BIOSPWD ####
##################################

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

function AdminPWD-Check
    {

    # Check AdminPWD status 0 = no PWD is set / 1 = PWD is set
    $PWstatus = Get-CimInstance -Namespace root/dcim/sysman/wmisecurity -ClassName PasswordObject -Filter "NameId='Admin'" | Select-Object -ExpandProperty IsPasswordSet

    Switch ($PWstatus)
        {

            0 {$AttributStringValue = 'disabled'}
            1 {$AttributStringValue = 'enabled'}

        }
    
    return $PWstatus,$AttributStringValue
    
    }



function Get-DellApp-Installed 
    {
        param(
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

function get-BIOSSettings 
    {

        [System.Collections.ArrayList]$BIOSCCTKData =  Get-Content "C:\temp\CCTK_Precision 7560.cctk"
        
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


################################################################
###  Program Section                                         ###
################################################################

###################################################
###  Program Section - BIOS Password            ###
###################################################

#############################################################
#### prepare PowerShell Environment for BIOS PWD request ####
#############################################################

# AZ PowerShell Module
$CheckPowerShellModule = Check-Module -ModuleName PowerShellGet -ModuleVersion $PowerShellGetVersion
# AZ PowerShell Module
$CheckPowerShellModule = Check-Module -ModuleName Az.Accounts -ModuleVersion $AzAccountsVersion
$CheckPowerShellModule = Check-Module -ModuleName Az.KeyVault -ModuleVersion $AzKeyVaultVersion

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

##################################
#### Disconnect from KeyVault ####
##################################
Disconnect-KeyVaultPWD

###################################################
###  Program Section - Dell Command | Update    ###
###################################################


#### Checking if Dell Command | Update and Dell Optimizer are installed on the client system
$CheckDCU = Get-DellApp-Installed -DellApp $DCUPath
$CheckDO = Get-DellApp-Installed -DellApp $DOPath

#### Checking system folder
$CheckDOPath = get-folderstatus -Path $env:ProgramData\$DOProgramData\DellOptimizer\ImportExport
$CheckTempPath = get-folderstatus -path $TempPath

#### generate folder if not exist
if ($CheckDOPath -ne $true) 
    {
        $TempDOPath = $env:ProgramData+"\"+$DOProgramData+"\DellOptimizer\ImportExport"
        Write-Host "Folder Optimizer Import is not available and will generate now"
        New-Item $TempDOPath -ItemType Directory -Force
        Write-Host "Folder Optimizer Import is not available and will generate now:"$env:ProgramData\$DOProgramData\DellOptimizer\ImportExport
    }
else 
    {
        Write-Host "Folder Optimizer Import"$env:ProgramData\$DOProgramData\DellOptimizer\ImportExport" is available"
    }

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
        Start-BitsTransfer -DisplayName "Dell Optimizer" -Source $DOConfigFile -Destination $DOImportPath
        Start-BitsTransfer -DisplayName "Dell Client BIOS Settings" -Source $BIOSConfigFile -Destination $TempPath
        #  Start-BitsTransfer -DisplayName "Dell Display Manager" -Source $DDMConfigFile -Destination $TempPath

    }
else 
    {
    
    Write-Host "BITS Service is disabled program stopps"
    exit 2

    }


#### Import Config Dell Command | Update and Dell Optimizer
## DCU Import
$DCUConfigFileName = get-ConfigFileName -DellToolName "DCU" -FilePath $TempPath -FileFormat xml
$DCUFullName = $DCUPath + $DCUProgramName
$DCUCLIArgument = $DCUParameter + $TempPath + $DCUConfigFileName
$DCUImportResult = Start-Process -FilePath $DCUFullName -ArgumentList $DCUCLIArgument -NoNewWindow -Wait -PassThru

$DCUImportResult.ExitCode

## DCU set BIOS PWD
$DCUBIOSArgument = $DCUBIOSParameter + $BIOSPWD
$DCUBIOSResult = Start-Process -FilePath $DCUFullName -ArgumentList $DCUBIOSArgument -Wait -PassThru

$DCUBIOSResult.ExitCode

## DO Import
$DOConfigFileName = get-ConfigFileName -DellToolName "DO" -FilePath $DOImportPath -FileFormat json
$DOFullName = $DOPath + $DOProgramName
$DOCLIArgument = $DOParameter + $DOConfigFileName
$DOImportResult = Start-Process -FilePath $DOFullName -ArgumentList $DOCLIArgument -NoNewWindow -Wait -PassThru

$DOImportResult.ExitCode

###################################################
###  Program Section - BIOS Settings            ###
###################################################

[System.Collections.ArrayList]$BIOSConfigData = get-BIOSSettings






###################################################
###  Program Section - Dell Optimizer           ###
###################################################



###################################################
###  Program Section - Dell Display Manager 2   ###
###################################################