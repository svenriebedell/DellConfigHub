<#
_author_ = Sven Riebe <sven_riebe@Dell.com>
_twitter_ = @SvenRiebe
_version_ = 1.0.1
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
1.0.1   Clean the registry value before DCU scan starts.
        Blocked drivers are now written as success in the registry value so that the value is not deleted again the next day by dcu. 


Knowing Issues
    - Dell Command | Update make a clean of registy on a regular base. This script need to be run on regluar base as well to cover this otherwise drivers could be deployed which normally are blocked.


#>

<#
.Synopsis
    This PowerShell starting the Dell Command | Update to identify missing Drivers. After collecting missing drivers reading the Release Date of each driver and compare it with the planned days of delayed deployment (UpdateRings). If a driver is to new for deployment based on your policy the driver will blocked for update. Next time you will run an update with Dell Command | Update this drivers will be ignored.
    IMPORTANT: This script does not reboot the system to apply or query system.
    IMPORTANT: Dell Command | Update need to install first on the devices.

.DESCRIPTION
   PowerShell helping to use different Updates Rings with Dell Command | Update. You can configure up to 8 different Rings. This script need to run each time if a new Update Catalog is availible to update the Blocklist as well.
   
#>

################################################################
###  Variables Section                                       ###
################################################################
$DellTools = @(
    [PSCustomObject]@{Name = "DCU"; Enabled = $true}
    [PSCustomObject]@{Name = "DO"; Enabled = $false}
    [PSCustomObject]@{Name = "DDM"; Enabled = $true}
    [PSCustomObject]@{Name = "BIOS"; Enabled = $true}
)

# You need to define the location of you Excel Sheet where the script could be find the assignments of Device-Name to Update-Ring
$DellConfigTable = 'https://dellconfighub.blob.core.windows.net/configmaster/DellDeviceConfiguration.xlsx'

$TempPath = "C:\Temp\"
$DCUParameter = "/configure -importSettings="


## Do not change ##
$DCUProgramName = ".\dcu-cli.exe"
$DCUPath = (Get-CimInstance -ClassName Win32_Product -Filter "Name like '%Dell%Command%Update%'").InstallLocation
$DeviceSKU = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
$Device = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Name


################################################################
###  Functions Section                                       ###
################################################################

function Get-DCU-Installed 
    {

    If($null -ne $DCUPath)
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
            [string]$DeviceName
        )
    
    $ExcelData = New-Object -ComObject Excel.Application
    $ReadFile = $ExcelData.workbooks.open($DellConfigTable,0,$true)
    ($ReadFile.ActiveSheet.UsedRange.Rows | Where-Object {$_.Columns["A"].Value2 -eq $DeviceName}).Value2

    }

function get-ConfigFileName 
    {
    
        param 
            (
                [string]$DellToolName
            )

        Set-Location $TempPath
        
        Get-ChildItem .\*.xml | Where-Object Name -Like "$DellToolName*" | Select-Object -ExpandProperty Name
        
        
        Set-Location \
    
    }


################################################################
###  Program Section                                         ###
################################################################

###################################################
###  Program Section - Dell Command | Update    ###
###################################################

#### Check if DCU is installed if not the script will end

if (($DellTools | Where-Object {$_.Name -match "DCU"} | Select-Object -ExpandProperty Enabled) -eq $true) 
    {
        ## get download path of config file for this machine
        $DCUConfigPath = (get-configdata -DeviceName $Device)[2]

        ## Download DCU configuration file to $TempPath folder
        Start-BitsTransfer -DisplayName "Dell Command | Update Configuration File" -Source $DCUConfigPath -Destination $TempPath
        
        ## get Name of configuration file
        $DCUConfigFileName = get-ConfigFileName -DellToolName "DCU"

        ## import DCU setting on client
        Set-Location -Path $DCUPath
        
        $CLIDCUCommand = $DCUParameter + $TempPath + $DCUConfigFileName
        $DCUImportResult = Start-Process -FilePath $DCUProgramName -ArgumentList $CLIDCUCommand -NoNewWindow -Wait -PassThru

        If ($DCUImportResult.ExitCode -eq 0)
            {
                $DCUImportMessage = "Dell Command | Update File:" + $DCUConfigFileName + " is successfull imported code:"+ $DCUImportResult.ExitCode + " " + $DCUImportResult.ExitTime
                Write-EventLog -LogName Dell -Source DCUImport -EventId 0 -EntryType SuccessAudit -Message $DCUImportMessage

            }
        else 
            {
                $DCUImportMessage = "Dell Command | Update File:" + $DCUConfigFileName + " is not imported code:"+ $DCUImportResult.ExitCode + " " + $DCUImportResult.ExitTime
                Write-EventLog -LogName Dell -Source DCUImport -EventId 2 -EntryType Error -Message $DCUImportMessage
            }

        Remove-Item -Path $TempPath$DCUConfigFileName
        Set-Location \

    }
else   
    {
    <# Action when all if and elseif conditions are false #>
    }