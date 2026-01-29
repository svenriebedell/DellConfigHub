# JSON-Datei einlesen
$jsonContent = Get-Content -Path "C:\Dell\Github\DellConfigHub\MasterfileADMXJSON.json" -Raw
$policyData = ConvertFrom-Json -InputObject $jsonContent

# ADMX-Datei erstellen
$admxContent = @"
<?xml version="1.0" encoding="utf-8"?>
<policyDefinitions revision="1.0" schemaVersion="1.0"
                 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <policyNamespaces>
    <target prefix="ConfigHub" namespace="ConfigHub"/>
    <using prefix="windows" namespace="Microsoft.Policies.Windows"/>
  </policyNamespaces>
  <resources minRequiredRevision="1.0" fallbackCulture="en-US"/>
  <categories>
    <category name="ConfigHub" displayName="ConfigHub_Policy">
      <category name="BIOS" displayName="BIOS_Settings">
"@

# BIOS-Policies
foreach ($policy in $policyData.Policies.BIOS) {
    $arguments = $policy.Argument -split ", "
    $admxContent += @"
        <policy name="$($policy.Name)" displayName="$($policy.Name)_Policy" explainText="$($policy.Description)" key="SOFTWARE\Microsoft\Policies\ConfigHub\BIOS\$($policy.Name)" class="Machine">
          <parentCategory ref="ConfigHub_BIOS"/>
          <supportedOn ref="windows:SUPPORTED_Windows_10_0_NOARM"/>
          <elements>
            <enum id="$($policy.Name)_Argument" valueName="Argument" default="Not Configured">
"@
    foreach ($argument in $arguments) {
        $admxContent += @"
              <item name="$argument">
                <value><name>$argument</name><value>$argument</value></value>
              </item>
"@
    }
    $admxContent += @"
            </enum>
          </elements>
        </policy>
"@
}

$admxContent += @"
      </category>
      <category name="Uninstall" displayName="Uninstall_Settings">
"@

# Uninstall-Policies
foreach ($policy in $policyData.Policies.Uninstall) {
    $types = $policy.Type -split ", "
    $admxContent += @"
        <policy name="Uninstall_$($policyData.Policies.Uninstall.IndexOf($policy))" displayName="Uninstall_Setting_$($policyData.Policies.Uninstall.IndexOf($policy))" explainText="$($policy.DescriptionMatchCode)" key="SOFTWARE\Microsoft\Policies\ConfigHub\Uninstall\$($policyData.Policies.Uninstall.IndexOf($policy))" class="Machine">
          <parentCategory ref="ConfigHub_Uninstall"/>
          <supportedOn ref="windows:SUPPORTED_Windows_10_0_NOARM"/>
          <elements>
            <text id="TXT_Uninstall_$($policyData.Policies.Uninstall.IndexOf($policy))_Name" valueName="Name"/>
            <text id="TXT_Uninstall_$($policyData.Policies.Uninstall.IndexOf($policy))_MatchCode" valueName="MatchCode"/>
            <enum id="Uninstall_$($policyData.Policies.Uninstall.IndexOf($policy))_Type" valueName="Type" default="Not Configured">
"@
    foreach ($type in $types) {
        $admxContent += @"
              <item name="$type">
                <value><name>$type</name><value>$type</value></value>
              </item>
"@
    }
    $admxContent += @"
            </enum>
          </elements>
        </policy>
"@
}

$admxContent += @"
      </category>
    </category>
  </categories>
</policyDefinitions>
"@

# ADMX-Datei speichern
$admxContent | Out-File -FilePath "C:\Temp\DellConfigHub.admx" -Encoding utf8

# ADML-Datei erstellen
$admlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<policyDefinitionResources revision="1.0" schemaVersion="1.0"
                         xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <displayName>ConfigHub_Policy</displayName>
  <description>ConfigHub Policy Definitions</description>
  <resources>
    <stringTable>
      <string id="ConfigHub">ConfigHub_Policy</string>
      <string id="BIOS">BIOS_Settings</string>
      <string id="Uninstall">Uninstall_Settings</string>
"@

# BIOS-Policies
foreach ($policy in $policyData.Policies.BIOS) {
    $admlContent += @"
      <string id="$($policy.Name)">$($policy.Name)_Policy</string>
      <string id="$($policy.Name)_HELP">$($policy.Description)</string>
"@
}

# Uninstall-Policies
foreach ($policy in $policyData.Policies.Uninstall) {
    $admlContent += @"
      <string id="Uninstall_$($policyData.Policies.Uninstall.IndexOf($policy))">Uninstall_Setting_$($policyData.Policies.Uninstall.IndexOf($policy))</string>
      <string id="Uninstall_$($policyData.Policies.Uninstall.IndexOf($policy))_HELP">$($policy.DescriptionMatchCode)</string>
"@
}

$admlContent += @"
    </stringTable>
  </resources>
</policyDefinitionResources>
"@

# ADML-Datei speichern
$admlContent | Out-File -FilePath "C:\Temp\DellConfigHub.adml" -Encoding utf8