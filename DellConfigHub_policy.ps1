<#
_author_ = Sven Riebe <sven_riebe@Dell.com>
_twitter_ = @SvenRiebe
_version_ = 2.0.0
_Dev_Status_ = Test
Copyright © 2026 Dell Inc. or its subsidiaries. All Rights Reserved.

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
1.0.1   Correct wrong import argument for DDM
2.0.0   Reworked Version for managing Dell BIOS settings by using a central policy file and allows admin to uninstall apps

Knowing Issues
- N/A

#>

<#
.Synopsis
    This PowerShell will deploy ADMX and ADML files and allows the system to set BIOS settings based on the ADMX.
    IMPORTANT: This script does not reboot the system to apply or query system.

.DESCRIPTION
   PowerShell helping to maintaining settings of Dell Client for BIOS settings and uninstall of unwanted apps.
#>

###############################################################
####                                                       ####
####                Function section                       ####
####                                                       ####
###############################################################

function Get-DellADMXPolicy
    {
                <#
        .Synopsis
        This function read the ADMX policy for Dell BIOS and Uninstall

        .Description
        This function will let get the policy setting from the system for Dell BIOS and Application uninstall

        Changelog:
            1.0.0   Initial Version

        .Parameter Policy
        Value defined which policy you want to read
            Options at the momant:
                BIOS
                Uninstall

        .Example
        This example will give you policy setting for Dell BIOS set by ADMX file
        Get-DellADMXPolicy -Policy BIOS

        #>

        param
            (
                [Parameter(mandatory=$true)][ValidateSet('BIOS','Uninstall')][String]$Policy
            )

    ###############################################################
    ####                                                       ####
    ####        Function variables declaration                 ####
    ####                                                       ####
    ###############################################################

    $ADMXPolicyPath = 'HKLM:\SOFTWARE\Policies\Dell\Config'
    $ConfigPathBIOS = Join-Path $ADMXPolicyPath -ChildPath 'BIOS'
    $ConfigPathUninstall = Join-Path $ADMXPolicyPath -ChildPath 'Uninstall'

    try
        {
            # Check if the ADMX policy exist
            if($Policy -eq 'BIOS')
                {
                    if(Test-Path $ConfigPathBIOS)
                        {
                            $ADMXPolicyDetails = Get-ItemProperty -Path $ConfigPathBIOS
                            Return $ADMXPolicyDetails
                        }
                    else
                        {
                            Return "Error: Dell BIOS ADMX policy not found"
                        }
                }
            elseif ($Policy -eq 'Uninstall')
                {
                    if(Test-Path $ConfigPathUninstall)
                        {
                            $ADMXPolicyDetails = Get-ItemProperty -Path $ConfigPathUninstall
                            Return $ADMXPolicyDetails
                        }
                    else
                        {
                            Return "Error: Dell BIOS ADMX policy not found"
                        }
                }
        }
    catch
        {
            return "Error: " + $_.Exception.Message
        }
    }

function DeployDellADMX
    {
        <#
        .Synopsis
        This function incl the needed ADMX and ADML as unicode file and will uncode this file and store it on C:\windows\policies\en-US

        .Description
        This function will used to deploy the admin ADMX and ADML files and can than exported and imported to GPO or Intune

        Changelog:
            1.0.0   Initial Version

        .Example
        This example will deploy the admin ADMX and ADML files to C:\windows\policies\en-US
        DeployDellADMX

        #>

        param
            (
                #no parameters
            )

    ###############################################################
    ####                                                       ####
    ####        Function variables declaration                 ####
    ####                                                       ####
    ###############################################################

    $ADMXFileName = "Dell_BIOS_ADMX.admx"
    $ADMLFileName = "Dell_BIOS_ADML.adml"
    $ADMXUnicode = ""
    $ADMLUnicode = ""
    $PolicyOSPath = "C:\Windows\PolicyDefinitions\en-US"
    $ConfigPathBIOS = Join-Path -Path $PolicyOSPath -ChildPath $ADMXFileName
    $ConfigPathUninstall = Join-Path -Path $PolicyOSPath -ChildPath $ADMXFileName

    try
        {
            if(Test-Path -Path $PolicyOSPath)
                {
                    # convert ADMX file
                    [IO.File]::WriteAllBytes($ConfigPathBIOS, [Convert]::FromBase64String($ADMXUnicode))

                    # convert ADML file
                    [IO.File]::WriteAllBytes($ConfigPathBIOS, [Convert]::FromBase64String($ADMLUnicode))

                    Return $true
                }
            else
                {
                    return "Error: C:\Windows\policies\en-US not found"
                }
        }
    catch
        {
            return "Error: " + $_.Exception.Message
        }
    }

function write-ConfigHubEvent
    {
        <#
        .Synopsis
        This function write Events to Microsoft Eventlog. Need adminrights for execution.

        .Description
        This function writes standardized information from the script to MS Eventlog.

        .Parameter Logname
        Value is the Name of the Eventlog it will be later under Application and Service Logs Default Dell

        .Parameter Source
        Value is the Resource and will be visible in the Event for filter options Default is RemediationScript

        .Parameter EntryType
        Value is the type of a Event like Error, Information, FailureAudit, SuccessAudit, Warning

        .Parameter EventID
        Value is a number for this event for filter options, the values are predefined for categories like MainScript, Function and Software Installation

        .Parameter Message
        Value is a message that will be visible in Event, it could be a string or JSON or XML but only one message for each event.

        Changelog:
            1.0.0   Initial Version


        .Example
        # Write a Microsoft Event to Application and Service Logs for LogName DellConfigHub and Source ConfigHub with ID 2 for Information with the message body "Test message"
        write-ConfigHubEvent -Logname DellConfigHub -Source ConfigHub -EntryType Information -EventID '2-InformationScript' -Message "Test message"

        #>
        param
            (

                [Parameter(mandatory=$false)][ValidateSet('DellConfigHub')]$Logname,
                [Parameter(mandatory=$false)][ValidateSet('ConfigHub')]$Source,
                [Parameter(mandatory=$false)][ValidateSet('Error', 'Information', 'FailureAudit', 'SuccessAudit', 'Warning')]$EntryType='Information',
                [Parameter(mandatory=$true)][ValidateSet('0-SuccessScript','1-ErrorScript','2-InformationScript','3-WarningScript')][String]$EventID,
                [Parameter(mandatory=$true)]$Message

            )
        #########################################################################################################
        ####                                    Variable Section                                             ####
        #########################################################################################################

        # Log Parameters

        #########################################################################################################
        ####                                Function Program Section                                         ####
        #########################################################################################################
        # prepare the logname and ressource name
        $checkSource = [System.Diagnostics.EventLog]::SourceExists($source)
        if ($checkSource -ne $true)
            {
                try
                    {
                        [System.Diagnostics.EventLog]::CreateEventSource($source, $logName)
                        Write-Verbose "Event source '$source' created for log '$logName'." -Verbose
                    }
                catch
                    {
                        Write-Verbose "Event source '$source' fail to create for log '$logName'." -Verbose
                        return $false
                    }

            }
        else
            {
                Write-Verbose "Event source '$source' already exists." -Verbose
            }


        # modify EventID to number only
        [int]$EventID = switch ($EventID)
                    {
                        '0-SuccessScript'             {0}
                        '1-ErrorScript'               {1}
                        '2-InformationScript'         {2}
                        '3-WarningScript'             {3}
                        Default {2}
                    }

        # Value validation if Entrytype match to EventID if not it change the Entrytype to the correct type

        if ($EventID -eq 0)
            {
                $EntryType = 'SuccessAudit'
            }
        if ($EventID -eq 1)
            {
                $EntryType = 'Error'
            }
        if ($EventID -eq 2)
            {
                $EntryType = 'Information'
            }
        if ($EventID -eq 3)
            {
                $EntryType = 'Warning'
            }

        try
            {
                # Initialize Eventlog for reporting and Debugging
                $evt=new-object System.Diagnostics.EventLog($logName)
                $evt.Source=$source

                #write event by .net
                $evt.WriteEntry($Message,$EntryType,$EventID)
                Write-Verbose "Eventlog is created successful" -Verbose
                Return $true
            }
        catch
            {
                Write-Verbose "Eventlog could not created" -Verbose
                Return $false
            }
    }

function set-BIOSSetting
    {

        <#
        .Synopsis
        This function changing the Dell Client BIOS Settings by CIM

        .Description
        This function allows you agentless to set BIOS Pasword or to change BIOS Settings

        .Parameter SettingName
        Value is the name of the BIOS setting

        .Parameter SettingValue
        This is the value is the BIOS setting value, e.g. enabled or disabled or if you set/Change the new Password

        .Parameter BIOSPW
        This is the value is the existing BIOS Password set on the device. It will only needed if a BIOS Password is set on the device.


        Changelog:
            1.0.0 Initial Version
            1.0.1 add return for setting returncode to the mainscript
            1.0.2 switch from write-host to Write-Information, write-verbose and write-error


        .Example
        This example will set the Chassis Intrusion detection to SilentEnable, if the Device has no BIOS Admin Password.

        set-BIOSSetting -SettingName ChasIntrusion -SettingValue SilentEnable

        .Example
        This example will set the Chassis Intrusion detection to SilentEnable, if the Device has BIOS Admin Password.

        set-BIOSSetting -SettingName ChasIntrusion -SettingValue SilentEnable -BIOSPW <Your BIOS Admin PWD>

        .Example
        This example will set a new BIOS Admin Password for the first time

        set-BIOSSetting -SettingName Admin -SettingValue <Your BIOS Admin PWD>

        .Example
        This example will change BIOS Admin Password

        set-BIOSSetting -SettingName Admin -SettingValue <Your NEW BIOS Admin PWD> -BIOSPW <Your OLD BIOS Admin PWD>

        .Example
        This example will Clear BIOS Admin Password

        set-BIOSSetting -SettingName Admin -SettingValue ClearPWD -BIOSPW <Your OLD BIOS Admin PWD>

        #>

        param
            (

                [Parameter(mandatory=$true)] [String]$SettingName,
                [Parameter(mandatory=$true)] [String]$SettingValue,
                [Parameter(mandatory=$false)] [String]$BIOSPW

            )


        #########################################################################################################
        ####                                    Program Section                                              ####
        #########################################################################################################

        # connect BIOS Interface
        try
            {
                # get BIOS WMI Interface
                $BIOSInterface = Get-CimInstance -Namespace root\dcim\sysman\biosattributes -Class BIOSAttributeInterface -ErrorAction Stop
                $SecurityInterface = Get-CimInstance -Namespace root\dcim\sysman\wmisecurity -Class SecurityInterface -ErrorAction Stop
                Write-Information "BIOS Interface connected" -InformationAction Continue
            }
        catch
            {
                Write-Error "Error : BIOS interface access denied or unreachable"
                Write-Information "Status : false" -InformationAction Continue
                Return $false
            }


        # Check if BIOS Setting need BIOS Admin PWD
        try
            {
                # Check BIOS AttributName AdminPW is set
                $BIOSAdminPW = Get-CimInstance -Namespace root/dcim/sysman/wmisecurity -ClassName PasswordObject -Filter "NameId='Admin'" | Select-Object -ExpandProperty IsPasswordSet

                if ($BIOSAdminPW -match "1")
                    {
                        Write-Information "BIOS Admin PW is set on this Device" -InformationAction Continue

                        If ($null -eq $BIOSPW)
                            {
                                Write-Information "Message : required parameter BIOSPW is empty" -InformationAction Continue
                                Return $false, "3"
                                Return $false
                            }

                        #Get encoder for encoding password
                        $encoder = New-Object System.Text.UTF8Encoding

                        #encode the password
                        $AdminBytes = $encoder.GetBytes($BIOSPW)

                        If (($SettingName -ne "Admin") -and ($SettingName -ne "System"))
                            {
                                ######################################
                                ####  BIOS Setting with Admin PWD ####
                                ######################################

                                try
                                    {
                                        # Argument
                                        $argumentsWithPWD = @{
                                                                AttributeName=$SettingName;
                                                                AttributeValue=$SettingValue;
                                                                SecType=1;
                                                                SecHndCount=$AdminBytes.Length;
                                                                SecHandle=$AdminBytes;
                                                            }

                                        # Set a BIOS Attribute
                                        Write-Information "Set Bios" -InformationAction Continue
                                        $SetResult = Invoke-CimMethod -InputObject $BIOSInterface -MethodName SetAttribute -Arguments $argumentsWithPWD -ErrorAction Stop

                                        If ($SetResult.Status -eq 0)
                                            {
                                                Write-Information "Message : BIOS setting success" -InformationAction Continue
                                                return $true
                                            }
                                        else
                                            {
                                                switch ( $SetResult.Status )
                                                    {
                                                        0 { $result = 'Success' }
                                                        1 { $result = 'Failed' }
                                                        2 { $result = 'Invalid Parameter' }
                                                        3 { $result = 'Access Denied'  }
                                                        4 { $result = 'Not Supported' }
                                                        5 { $result = 'Memory Error'  }
                                                        6 { $result = 'Protocol Error' }
                                                        default { $result ='Unknown' }
                                                    }
                                                Write-Information "Message : BIOS setting $result" -InformationAction Continue
                                                return $false, $SetResult.Status
                                            }
                                    }
                                catch
                                    {
                                        $errMsg = $_.Exception.Message
                                        Write-Information $errMsg -InformationAction Continue
                                        If ($SetResult.Status -eq 0)
                                            {
                                                Write-Information "Message : BIOS setting success" -InformationAction Continue
                                                return $true
                                            }
                                        else
                                            {
                                                        switch ( $SetResult.Status )
                                                            {
                                                                0 { $result = 'Success' }
                                                                1 { $result = 'Failed' }
                                                                2 { $result = 'Invalid Parameter' }
                                                                3 { $result = 'Access Denied'  }
                                                                4 { $result = 'Not Supported' }
                                                                5 { $result = 'Memory Error'  }
                                                                6 { $result = 'Protocol Error' }
                                                                default { $result ='Unknown' }
                                                            }
                                                        Write-Information "Message : BIOS Password setting $result" -InformationAction Continue
                                                        return $false, $SetResult.Status
                                                        Return $false
                                            }
                                    }
                            }
                        else
                            {
                                ################################################
                                ####  BIOS Change/Delete Admin or Sytem PWD ####
                                ################################################
                                try
                                    {
                                        If($SettingValue -eq "ClearPWD")
                                            {
                                                Write-Information "Admin PWD clear" -InformationAction Continue
                                                # Argument
                                                $argumentsWithPWD = @{
                                                                        NameId=$SettingName;
                                                                        NewPassword="";
                                                                        OldPassword=$BIOSPW;
                                                                        SecType=1;
                                                                        SecHndCount=$AdminBytes.Length;
                                                                        SecHandle=$AdminBytes;
                                                                    }
                                            }
                                        else
                                            {
                                                Write-Information "Admin PWD change" -InformationAction Continue
                                                # Argument
                                                $argumentsWithPWD = @{
                                                                        NameId=$SettingName;
                                                                        NewPassword=$SettingValue;
                                                                        OldPassword=$BIOSPW;
                                                                        SecType=1;
                                                                        SecHndCount=$AdminBytes.Length;
                                                                        SecHandle=$AdminBytes;
                                                                    }
                                            }


                                        # Set a BIOS Attribute
                                        $SetResult = Invoke-CimMethod -InputObject $SecurityInterface -MethodName SetnewPassword -Arguments $argumentsWithPWD #-ErrorAction Stop

                                        If ($SetResult.Status -eq 0)
                                            {
                                                Write-Information "Message : BIOS Password setting success" -InformationAction Continue
                                                return $true
                                            }
                                        else
                                            {
                                                switch ( $SetResult.Status )
                                                    {
                                                        0 { $result = 'Success' }
                                                        1 { $result = 'Failed' }
                                                        2 { $result = 'Invalid Parameter' }
                                                        3 { $result = 'Access Denied'  }
                                                        4 { $result = 'Not Supported' }
                                                        5 { $result = 'Memory Error'  }
                                                        6 { $result = 'Protocol Error' }
                                                        default { $result ='Unknown' }
                                                    }
                                                Write-Information "Message : BIOS Password setting $result" -InformationAction Continue
                                                return $false, $SetResult.Status
                                            }
                                    }
                                catch
                                    {
                                        $errMsg = $_.Exception.Message
                                        Write-Information $errMsg -InformationAction Continue
                                        If ($SetResult.Status -eq 0)
                                            {
                                                Write-Information "Message : BIOS Password setting success" -InformationAction Continue
                                                return $true
                                            }
                                        else
                                            {
                                                switch ( $SetResult.Status )
                                                    {
                                                        0 { $result = 'Success' }
                                                        1 { $result = 'Failed' }
                                                        2 { $result = 'Invalid Parameter' }
                                                        3 { $result = 'Access Denied'  }
                                                        4 { $result = 'Not Supported' }
                                                        5 { $result = 'Memory Error'  }
                                                        6 { $result = 'Protocol Error' }
                                                        default { $result ='Unknown' }
                                                    }
                                                Write-Information "Message : BIOS Password setting $result" -InformationAction Continue
                                                return $false, $SetResult.Status
                                                Return $false
                                            }
                                    }
                            }
                    }
                Else
                    {
                        Write-Information "No BIOS Admin PW is set on this Device" -InformationAction Continue

                        If (($SettingName -ne "Admin") -and ($SettingName -ne "System"))
                            {
                                #########################################
                                ####  BIOS Setting without Admin PWD ####
                                #########################################
                                try
                                    {
                                        # Argument
                                        $argumentsNoPWD = @{
                                                                AttributeName=$SettingName;
                                                                AttributeValue=$SettingValue;
                                                                SecType=0;
                                                                SecHndCount=0;
                                                                SecHandle=@()
                                                            }

                                        Write-Information "Set Bios Settings" -InformationAction Continue
                                        # Set a BIOS Attribute ChasIntrusion to EnabledSilent (BIOS password is not set)
                                        $SetResult = Invoke-CimMethod -InputObject $BIOSInterface -MethodName SetAttribute -Arguments $argumentsNoPWD -ErrorAction Stop

                                        If ($SetResult.Status -eq 0)
                                            {
                                                Write-Information "Message : BIOS setting success" -InformationAction Continue
                                                return $true
                                            }
                                        else
                                            {
                                                switch ( $SetResult.Status )
                                                    {
                                                        0 { $result = 'Success' }
                                                        1 { $result = 'Failed' }
                                                        2 { $result = 'Invalid Parameter' }
                                                        3 { $result = 'Access Denied'  }
                                                        4 { $result = 'Not Supported' }
                                                        5 { $result = 'Memory Error'  }
                                                        6 { $result = 'Protocol Error' }
                                                        default { $result ='Unknown' }
                                                    }
                                                Write-Information "Message : BIOS setting $result" -InformationAction Continue
                                                return $false, $SetResult.Status
                                            }
                                    }
                                catch
                                    {
                                        $errMsg = $_.Exception.Message
                                        Write-Information $errMsg -InformationAction Continue
                                        Write-Information "Message : BIOS setting failed" -InformationAction Continue
                                        return $false, $SetResult.Status
                                        Return $false
                                    }


                            }
                        else
                            {
                                ######################################
                                ####  BIOS Set Admin or Sytem PWD ####
                                ######################################
                                try
                                    {

                                        # Argument
                                        $argumentsNoPWD = @{
                                                                NameId=$SettingName;
                                                                NewPassword=$SettingValue;
                                                                OldPassword="";
                                                                SecType=0;
                                                                SecHndCount=0;
                                                                SecHandle=@();
                                                            }

                                        Write-Information "Set Password" -InformationAction Continue

                                        # Set a BIOS Passwords
                                        $SetResult = Invoke-CimMethod -InputObject $SecurityInterface -MethodName SetnewPassword -Arguments $argumentsNoPWD -ErrorAction Stop

                                        If ($SetResult.Status -eq 0)
                                            {
                                                Write-Information "Message : BIOS Password setting success" -InformationAction Continue
                                                return $true
                                            }
                                        else
                                            {
                                                switch ( $SetResult.Status )
                                                    {
                                                        0 { $result = 'Success' }
                                                        1 { $result = 'Failed' }
                                                        2 { $result = 'Invalid Parameter' }
                                                        3 { $result = 'Access Denied'  }
                                                        4 { $result = 'Not Supported' }
                                                        5 { $result = 'Memory Error'  }
                                                        6 { $result = 'Protocol Error' }
                                                        default { $result ='Unknown' }
                                                    }
                                                Write-Information "Message : BIOS setting $result" -InformationAction Continue
                                                return $false, $SetResult.Status
                                            }
                                    }
                                catch
                                    {
                                        $errMsg = $_.Exception.Message
                                        Write-Information $errMsg -InformationAction Continue
                                        Write-Information "Message : BIOS setting failed" -InformationAction Continue
                                        return $false, $SetResult.Status
                                        Return $false
                                    }
                            }
                    }
            }
        catch
            {
                $errMsg = $_.Exception.Message
                Write-Information $errMsg -InformationAction Continue
                If ($SetResult.Status -eq 0)
                    {
                        Write-Information "Message : BIOS setting success" -InformationAction Continue
                        return $true
                    }
                else
                    {
                        switch ( $SetResult.Status )
                            {
                                0 { $result = 'Success' }
                                1 { $result = 'Failed' }
                                2 { $result = 'Invalid Parameter' }
                                3 { $result = 'Access Denied'  }
                                4 { $result = 'Not Supported' }
                                5 { $result = 'Memory Error'  }
                                6 { $result = 'Protocol Error' }
                                default { $result ='Unknown' }
                            }
                        Write-Information "Message : BIOS Password setting $result" -InformationAction Continue
                        return $false, $SetResult.Status
                    }
                Write-Information "Status : False" -InformationAction Continue
                Return $false
            }
    }

function Uninstall-WinApplication
    {
        <#
            .Synopsis
            This function will uninstall an win32 application and APPX

            .Description
            This function allows you to uninstall an Win 32 application from the Windows OS or APPX

            .Parameter SoftwareName
            Value is the name of the the application

            .Parameter SoftwareType
            Value is the kind of type of application, if it is Win32 or APPX


            Changelog:
                1.0.0 Initial Version


            .Example
            This example will uninstall the Dell Command | Monitor and it is Win32 application

            Remove-App -SoftwareName "Dell Command | Monitor" -SoftwareType Win32

            #>

        param
            (
                [Parameter(Mandatory=$true)][string]$SoftwareName,
                [Parameter(Mandatory=$true)][ValidateSet("Win32","APPX")][string]$SoftwareType
            )

        Try
            {
                # add asterik to the software name
                $SoftwareName = "*$SoftwareName*"

                if ($SoftwareType -eq "Win32")
                    {
                        if ($software)
                            {
                                Try
                                    {
                                        $software.Uninstall()
                                        Write-Output "Software '$SoftwareName' has been uninstalled."
                                    }
                                catch
                                    {
                                        Write-Output "Software '$SoftwareName' not found."
                                    }
                            }
                        else
                            {
                                Write-Output "Software '$SoftwareName' not found."
                            }
                    }
                elseif ($SoftwareType -eq "APPX")
                    {
                        try
                            {
                                Get-AppxPackage -Name $SoftwareName | Remove-AppxPackage
                                Write-Output "Appx "$SoftwareName" has been uninstalled."
                            }
                        catch
                            {
                                Write-Output "App $SoftwareName not found."
                            }
                    }

                # get all Win32 Applications with the same match code
                [Array]$software = Get-CimInstance -ClassName Win32_Product | Where-Object {$_.Name -like $SoftwareName}


            }
        catch
            {
                return "Error: " + $_.Exception.Message
            }

    }

###############################################################
####                                                       ####
####                Varible section                        ####
####                                                       ####
###############################################################

$ActivePolicyAction = @(
                            [PSCustomObject]@{ PolicyName = "BIOS"; ActivePolicy = $true}
                            [PSCustomObject]@{ PolicyName = "Uninstall"; ActivePolicy = $true}
                        )

###############################################################
####                                                       ####
####                Program section                        ####
####                                                       ####
###############################################################

try
    {
        foreach ($Policy in $ActivePolicyAction)
            {
                If($Policy.ActivePolicy -eq $true)
                    {
                        # get details from ADMX file by reading Registry
                        $PolicyDetails = Get-DellADMXPolicy -Policy $Policy.PolicyName

                        If($null -ne $PolicyDetails)
                            {
                                if ($Policy.PolicyName -eq "BIOS")
                                    {
                                        # Section for BIOS Settings

                                    }
                                elseif ($Policy.PolicyName -eq "Uninstall")
                                    {
                                        # Section for Uninstall applications
                                    }
                            }
                        else
                            {
                                Write-Information "Error: $($Policy.PolicyName) policy is empty" -InformationAction Continue
                            }
                    }
                else
                    {
                        Write-Information "Skipping $($Policy.PolicyName) policy" -InformationAction Continue
                    }
            }
    }
catch
    {
        Write-Output "Error: " + $_.Exception.Message
    }