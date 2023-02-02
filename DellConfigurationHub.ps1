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
    [PSCustomObject]@{Name = "DOSetting"; Enabled = $true}
    [PSCustomObject]@{Name = "DDM"; Enabled = $false}
    [PSCustomObject]@{Name = "BIOS"; Enabled = $true}
)

# You need to define the location of you Excel Sheet where the script could be find the assignments of Device-Name to Update-Ring
$DellConfigTable = 'https://dellconfighub.blob.core.windows.net/configmaster/DellDeviceConfiguration.xlsx'

$TempPath = "C:\Temp\"
$DCUParameter = "/configure -importSettings="
$DOParameter = "/configure -importfile="


## Do not change ##
$DCUProgramName = "dcu-cli.exe"
$DCUPath = (Get-CimInstance -ClassName Win32_Product -Filter "Name like '%Dell%Command%Update%'").InstallLocation
$DCUGroup = Get-ItemPropertyValue HKLM:\SOFTWARE\Dell\DellConfigHub\DellCommandUpdate -Name UpdateGroup
$DCUConfigFile = Get-ItemPropertyValue HKLM:\SOFTWARE\Dell\DellConfigHub\DellCommandUpdate -Name UpdateFile
$DOProgramName = "do-cli.exe"
$DOPath = (Get-CimInstance -ClassName Win32_Product -Filter "Name like '%Dell Optimizer%'").InstallLocation
$DOImportPath = Get-ChildItem -path $env:ProgramData -Recurse ImportExport -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

$DeviceSKU = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
$Device = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Name


################################################################
###  Functions Section                                       ###
################################################################

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

function get-configdata 
    {
    param 
        (
            [Parameter(mandatory=$true)][string]$DeviceName
        )
    
    $ExcelData = New-Object -ComObject Excel.Application
    $ReadFile = $ExcelData.workbooks.open($DellConfigTable,0,$true)
    ($ReadFile.ActiveSheet.UsedRange.Rows | Where-Object {$_.Columns["A"].Value2 -eq $DeviceName}).Value2

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


################################################################
###  Program Section                                         ###
################################################################

###################################################
###  Program Section - Dell Command | Update    ###
###################################################


#### Checking if Dell Command | Update and Dell Optimizer are installed on the client system
$CheckDCU = Get-DellApp-Installed -DellApp $DCUPath
$CheckDO = Get-DellApp-Installed -DellApp $DOPath


#### get configuration files Dell Command | Update, Dell Optimizer, Dell Display Manager and Dell BIOS Settings for client system
$DOConfigFile = (get-configdata -DeviceName $Device)[3]
$BIOSConfigFile = (get-configdata -DeviceName $Device)[4]
## $DDMConfigFile = (get-configdata -DeviceName $Device)[5]   ## DDM coming later

#### Download Configuration Files to client systems
$CheckBITS = Get-Service | Where-Object Name -EQ BITS

If ($CheckBITS.Status -eq "Running")
    {
        Write-Host "BITS Service is status running"
        Start-BitsTransfer -DisplayName "Dell Command | Update Configuration File" -Source $DCUConfigFile -Destination $TempPath
        #Start-BitsTransfer -DisplayName "Dell Optimizer" -Source $DOConfigFile -Destination $DOImportPath
        #Start-BitsTransfer -DisplayName "Dell Client BIOS Settings" -Source $BIOSConfigFile -Destination $TempPath
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

<## DO Import
$DOConfigFileName = get-ConfigFileName -DellToolName "DO" -FilePath $DOImportPath -FileFormat json
$DOFullName = $DOPath + $DOProgramName
$DOCLIArgument = $DOParameter + $DOConfigFileName
$DOImportResult = Start-Process -FilePath $DOFullName -ArgumentList $DOCLIArgument -NoNewWindow -Wait -PassThru

$DOImportResult.ExitCode #>