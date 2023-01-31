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
    This PowerShell is deleting registry values for additonal script to define which update policy the client system will get assigned by AAD Group
    IMPORTANT: This script does not reboot the system to apply or query system.
    IMPORTANT: Dell Command | Update need to install first on the devices.

.DESCRIPTION
   PowerShell deleting UpdateRings informations for Dell Command | Update based on AAD Groups
#>

################################################################
###  Variables Section                                       ###
################################################################
$RegMainPath = "HKLM:\SOFTWARE\DELL\DellConfigHub"
$RegAppPath = "HKLM:\SOFTWARE\DELL\DellConfigHub\DellCommandUpdate"


################################################################
###  Program Section                                         ###
################################################################

## Checking Registry Paths exist
$CheckRegMainPath = Test-Path -Path $RegMainPath
$CheckRegAppPath = Test-Path -Path $RegAppPath

## checking Main path
If ($CheckRegMainPath -eq $true)
    {
        Write-Host "Path $RegMainPath is available"

        if ($CheckRegAppPath -eq $true)
            {

                Write-Host "Path $RegAppPath is available"
                Remove-ItemProperty -Path $RegAppPath -Name UpdatePolicy  -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $RegAppPath -Name UpdateSetTime -Force -ErrorAction SilentlyContinue 

            }
        else 
            {
            
                Write-Host "Path $RegAppPath is not available"

            }

    }
else 
    {
    
        Write-Host "Path $RegMainPath is not available"

    }