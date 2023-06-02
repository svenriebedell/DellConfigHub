# DellConfigurationHub
Newest Version: 1.0.0

Changelog:
1.0.0 First public version

##Requirements:
- The desired Dell Management Tools must be installed first
- Script needs AZ PowerShell Modules. The script need rights to allow to install this Modules find not installed on machine
- Cloud or Onpremise Storeage to store configurations files.


##Description
The goal of the project is to automate the configuration of the most used Dell management tools. Currently supported are the Dell Client BIOS, Dell Command | Update, Dell Display Manager 2.x and Dell Opitimizer. The project is currently in experimental status, so the type of configuration is limited to the import of previously prepared configuration files.
To create the necessary configuration files, you can use the existing Dell management tools and then export their settings and distribute them automatically via the DellConfigHub.
