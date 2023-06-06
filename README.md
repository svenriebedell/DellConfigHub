# DellConfigurationHub
Latest Version: 1.0.0

Changelog:
1.0.0 First public version

##Requirements:
- The desired Dell Management Tools must be installed first
- Script needs AZ PowerShell Modules. The script need rights to allow to install this Modules find not installed on machine
- Cloud or Onpremise Storeage to store configurations files.
- Run processes with BIOS Passwords you need to change the script or using Microsoft KeyVault https://github.com/svenriebedell/KeyVaultBIOSPW


##Description
The goal of the project is to automate the configuration of the most used Dell management tools. Currently supported are the Dell Client BIOS, Dell Command | Update, Dell Display Manager 2.x and Dell Opitimizer. The project is currently in experimental status, so the type of configuration is limited to the import of previously prepared configuration files.
To create the necessary configuration files, you can use the existing Dell management tools and then export their settings and distribute them automatically via the DellConfigHub.

**Legal disclaimer**: THE INFORMATION IN THIS PUBLICATION IS PROVIDED 'AS-IS.' DELL MAKES NO REPRESENTATIONS OR WARRANTIES OF ANY KIND WITH RESPECT TO THE INFORMATION IN THIS PUBLICATION, AND SPECIFICALLY DISCLAIMS IMPLIED WARRANTIES OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. In no event shall Dell Technologies, its affiliates or suppliers, be liable for any damages whatsoever arising from or related to the information contained herein or actions that you decide to take based thereon, including any direct, indirect, incidental, consequential, loss of business profits or special damages, even if Dell Technologies, its affiliates or suppliers have been advised of the possibility of such damages.

## How it works
This project consists of two parts:

1. ADMX DellConfigHub (for using with GPO or Intune)
2. PowerShell Script **(DellConfigurationHub_policy.ps1)**

We use the ADMX file to roll out the desired settings on the client machines. The ADMX can be used as GPO or as Imported Administrative Templates in Intune. The current version of the ADMX currently supports the provisioning of drive directories and some individual settings for testing. The ADMX provides for the creation of registry keys which are then used by the PowerShell script. The script reads the registry values and starts the download of the required configuration files via BITS and imports them into the respective Dell client management product.

Support Dell Client Management Software:
- Dell Client BIOS Settings by WMI
- Dell Command | Update Classic and Universal App
- Dell Optimizer 4.x and newer
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



