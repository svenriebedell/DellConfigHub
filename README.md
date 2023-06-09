# DellConfigurationHub
Latest Version: 1.0.0

Changelog:
1.0.0 First public version

## Requirements:
- The desired Dell Management Tools must be installed first
- Script needs AZ PowerShell Modules
- Cloud or Onpremise Storage to store configurations files.
- Run processes with BIOS Passwords you need to change the script or using my Microsoft KeyVault project https://github.com/svenriebedell/KeyVaultBIOSPW


## Description
The goal of this project is to automate the configuration of the most used Dell management tools. Currently supported are the Dell Client BIOS, Dell Command | Update, Dell Display Manager 2.x and Dell Opitimizer (Dell Power Manager over Dell Optimizer). The project is currently in experimental status, so the type of configuration is limited to the import of previously prepared configuration files.
To create the necessary configuration files, you can use the existing Dell Management tools and then export their settings and distribute them automatically via the DellConfigHub.

**Legal disclaimer**: THE INFORMATION IN THIS PUBLICATION IS PROVIDED 'AS-IS.' DELL MAKES NO REPRESENTATIONS OR WARRANTIES OF ANY KIND WITH RESPECT TO THE INFORMATION IN THIS PUBLICATION, AND SPECIFICALLY DISCLAIMS IMPLIED WARRANTIES OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. In no event shall Dell Technologies, its affiliates or suppliers, be liable for any damages whatsoever arising from or related to the information contained herein or actions that you decide to take based thereon, including any direct, indirect, incidental, consequential, loss of business profits or special damages, even if Dell Technologies, its affiliates or suppliers have been advised of the possibility of such damages.

## How it works
This project consists of two parts:

1. ADMX DellConfigHub (for using with GPO or Intune)
2. PowerShell Script **(DellConfigurationHub_policy.ps1)**

We use the ADMX file to roll out the desired settings on the client machines. The ADMX can be used as GPO or as Imported Administrative Templates in Intune. The current version of the ADMX currently supports the provisioning of drive directories and some individual settings for testing. The ADMX provides for the creation of registry keys which are then used by the PowerShell script. The script reads the registry values and starts the download of the required configuration files via BITS and imports them into the respective Dell client management product.

Support Dell Client Management Software:
- Dell Client BIOS Settings by WMI
- Dell Command | Update Classic and Universal App
- Dell Optimizer 4.x and newer / Dell Power Manager over Dell Optimizer
- Dell Display Manager 2.x and newer

The script must be executed on the client machines. Exemplarily in this text I do this with Intune, it also works with other solutions.


## PowerShell Script Options
The provided PowerShell script **(DellConfigurationHub_policy.ps1)** need to run on local machines by Taskplan, Intune or other solutions.

### Enable or disable Software configuration
![image](https://github.com/svenriebedell/DellConfigurationHub/assets/99394991/9a55eb11-32d3-4c40-8d7f-1696f5ab9448)

The Value could be Change to $true or $false. If value $true you select this application to be configured on next time the script will be run.

![image](https://github.com/svenriebedell/DellConfigurationHub/assets/99394991/c7c2ef8f-ad5b-4989-8b9b-4e631f80141d)

If you set value $true and there is no policy set by ADMX the script will be deactive this configuration.

To exclude any Microsoft KeyVault connection information I am using an excel sheet and secure the access to this by standard solution for authenifications like ADD or certificate. In this example the XLSX will be stored on Microsoft Blob Storage but you can use other locations as well but you need to tell the script where it could find your XLSX.

![image](https://github.com/svenriebedell/DellConfigurationHub/assets/99394991/d9095ade-207e-4c07-8760-d967cfd7727f)

## Explaining ADMX deployment

This Github providing a ADMX Template, this will set RegistryKey on local machine **HKLM:\Software\Dell\DellConfigHub** these keys will be read by PowerShell script.
The ADMX DellConfigHub has 4 Section:
1. BIOS (Path CCTK Config-File and BIOS Setting)
2. DellCommandUpdate (Path DCU Config-File and Update Ring)
3. DellDisplayManager (Path DDM Config-File)
4. DellOptimizer (Path DO Config-File, Application, DO Settings)

![image](https://github.com/svenriebedell/DellConfigurationHub/assets/99394991/838c42b7-d39e-4b1a-b680-fe73030761ec)

The first release have some restrictions it allows you to define the File to import the required settings but e.g. single BIOS settings will shown in the ADMX but it will later availible to execute.

The ADMX could be used as normal by Group Policy or you can use the ADMX Import Function of Microsoft Intune (Preview)

![image](https://github.com/svenriebedell/DellConfigurationHub/assets/99394991/df417f2a-062b-4da7-8963-62d9666e5ee4)

If you have imported the ADMX you can configure you own client configuration profile by using the ADMX

![image](https://github.com/svenriebedell/DellConfigurationHub/assets/99394991/2719eb3c-d464-43ac-948c-f0d545e0665c)

If you Configuration Policy is deployed successful you can run the PowerShell Script.
The PowerShell script could be run by Taskplaner, Intune Remediation/PowerShell or other solutions, like you want.

![AACDF203-3CAF-4E48-B0BA-062B732D7B24](https://github.com/svenriebedell/DellConfigurationHub/assets/99394991/ddbd3d80-0974-479c-8279-22a46369d015)

At the moment the protokoll will be reported to the execution Terminal in future releases the results will be saved in Mircosoft Event for better maintaining.

**Planed features:**
- BIOS Settings without CCTK File
- Dell Optimizer Setting without JSON File
- Dell Display Manager 2.x mulit Display import
- Microsoft Event runtime logging of PowerShell
- tdb
