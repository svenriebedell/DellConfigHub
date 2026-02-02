#requires -Version 7.0
<#
Sicherheitsmodell:
- Master-Passwort wird NIE gespeichert.
- KDF: PBKDF2-SHA256, default 200.000 Iterationen (anpassbar).
- Verschlüsselung: AES-256-CBC (PKCS7) + HMAC-SHA256 über (salt||iv||ciphertext).
- Ausgabeformat: Base64(JSON) mit Feldern: v, alg, iter, salt, iv, ct, hmac.
- Registry ist NUR Speicher für den Ciphertext-Blob. Sicherheit hängt am Master-Passwort.
#>

function New-RandomBytes {
    param([Parameter(Mandatory)][int]$Length)
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return $bytes
}

function Convert-SecureStringToUtf8Bytes {
    param([Parameter(Mandatory)][securestring]$SecureString)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        return [System.Text.Encoding]::UTF8.GetBytes($plain)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Protect-SecretWithPassword {
    [CmdletBinding(DefaultParameterSetName='Secure')]
    param(
        [Parameter(Mandatory)][securestring]$MasterPassword,
        [Parameter(Mandatory, ParameterSetName='Plain')][string]$Secret,
        [Parameter(Mandatory, ParameterSetName='Secure')][securestring]$SecretSecure,
        [int]$Iterations = 200000
    )

    # Secret zu Bytes
    $secretBytes =
        if ($PSCmdlet.ParameterSetName -eq 'Plain') {
            [System.Text.Encoding]::UTF8.GetBytes($Secret)
        } else {
            Convert-SecureStringToUtf8Bytes -SecureString $SecretSecure
        }

    $salt = New-RandomBytes -Length 16
    $iv   = New-RandomBytes -Length 16

    # MasterPasswort -> Bytes
    $mpwBytes = Convert-SecureStringToUtf8Bytes -SecureString $MasterPassword

    try {
        # KDF: 64 Byte ableiten, 32 für AES, 32 für HMAC
        $kdf = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
            $mpwBytes, $salt, $Iterations, [System.Security.Cryptography.HashAlgorithmName]::SHA256
        )
        $keyMaterial = $kdf.GetBytes(64)
        $encKey = $keyMaterial[0..31]
        $macKey = $keyMaterial[32..63]

        # AES-256-CBC Verschlüsselung
        $aes = [System.Security.Cryptography.Aes]::Create()
        try {
            $aes.KeySize = 256
            $aes.BlockSize = 128
            $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
            $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
            $aes.Key = $encKey
            $aes.IV  = $iv

            $encryptor = $aes.CreateEncryptor()
            $cipher = $encryptor.TransformFinalBlock($secretBytes, 0, $secretBytes.Length)
        } finally {
            $aes.Dispose()
        }

        # HMAC über salt||iv||cipher
        $concat = New-Object byte[] ($salt.Length + $iv.Length + $cipher.Length)
        [Array]::Copy($salt, 0, $concat, 0, $salt.Length)
        [Array]::Copy($iv,   0, $concat, $salt.Length, $iv.Length)
        [Array]::Copy($cipher, 0, $concat, $salt.Length + $iv.Length, $cipher.Length)

        $hmac = New-Object System.Security.Cryptography.HMACSHA256 ($macKey)
        $tag = $hmac.ComputeHash($concat)

        # JSON-Blob aufbereiten
        $obj = [pscustomobject]@{
            v    = 1
            alg  = 'PBKDF2-SHA256/AES-256-CBC/HMAC-SHA256'
            iter = $Iterations
            salt = [Convert]::ToBase64String($salt)
            iv   = [Convert]::ToBase64String($iv)
            ct   = [Convert]::ToBase64String($cipher)
            hmac = [Convert]::ToBase64String($tag)
        }
        $json = $obj | ConvertTo-Json -Compress
        $b64  = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($json))
        return $b64
    }
    finally {
        # Speicherbest-effort "säubern"
        [Array]::Clear($secretBytes, 0, $secretBytes.Length) 2>$null
        [Array]::Clear($mpwBytes, 0, $mpwBytes.Length) 2>$null
        [Array]::Clear($keyMaterial, 0, $keyMaterial.Length) 2>$null
        [Array]::Clear($encKey, 0, $encKey.Length) 2>$null
        [Array]::Clear($macKey, 0, $macKey.Length) 2>$null
    }
}

function Unprotect-SecretWithPassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][securestring]$MasterPassword,
        [Parameter(Mandatory)][string]$ProtectedBlobBase64,
        [switch]$AsPlainText  # default: SecureString
    )

    $json = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($ProtectedBlobBase64))
    $obj  = $json | ConvertFrom-Json

    if ($obj.v -ne 1) { throw "Unsupported blob version: $($obj.v)" }
    $salt = [Convert]::FromBase64String($obj.salt)
    $iv   = [Convert]::FromBase64String($obj.iv)
    $ct   = [Convert]::FromBase64String($obj.ct)
    $tag  = [Convert]::FromBase64String($obj.hmac)
    $iter = [int]$obj.iter

    $mpwBytes = Convert-SecureStringToUtf8Bytes -SecureString $MasterPassword

    try {
        # Keys ableiten
        $kdf = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
            $mpwBytes, $salt, $iter, [System.Security.Cryptography.HashAlgorithmName]::SHA256
        )
        $keyMaterial = $kdf.GetBytes(64)
        $encKey = $keyMaterial[0..31]
        $macKey = $keyMaterial[32..63]

        # HMAC prüfen (konstante Zeit – best effort)
        $concat = New-Object byte[] ($salt.Length + $iv.Length + $ct.Length)
        [Array]::Copy($salt, 0, $concat, 0, $salt.Length)
        [Array]::Copy($iv,   0, $concat, $salt.Length, $iv.Length)
        [Array]::Copy($ct,   0, $concat, $salt.Length + $iv.Length, $ct.Length)
        $hmac = New-Object System.Security.Cryptography.HMACSHA256 ($macKey)
        $calc = $hmac.ComputeHash($concat)
        if ($calc.Length -ne $tag.Length) { throw "HMAC length mismatch." }

        $mismatch = 0
        for ($i=0; $i -lt $calc.Length; $i++) { $mismatch = $mismatch -bor ($calc[$i] -bxor $tag[$i]) }
        if ($mismatch -ne 0) { throw "HMAC verification failed (wrong password or tampered data)." }

        # Entschlüsseln
        $aes = [System.Security.Cryptography.Aes]::Create()
        try {
            $aes.KeySize = 256
            $aes.BlockSize = 128
            $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
            $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
            $aes.Key = $encKey
            $aes.IV  = $iv

            $decryptor = $aes.CreateDecryptor()
            $plainBytes = $decryptor.TransformFinalBlock($ct, 0, $ct.Length)
        } finally {
            $aes.Dispose()
        }

        $plain = [System.Text.Encoding]::UTF8.GetString($plainBytes)
        if ($AsPlainText) {
            return $plain
        } else {
            return (ConvertTo-SecureString -AsPlainText $plain -Force)
        }
    }
    finally {
        [Array]::Clear($mpwBytes, 0, $mpwBytes.Length) 2>$null
        [Array]::Clear($keyMaterial, 0, $keyMaterial.Length) 2>$null
        [Array]::Clear($encKey, 0, $encKey.Length) 2>$null
        [Array]::Clear($macKey, 0, $macKey.Length) 2>$null
    }
}

function Set-EncryptedSecretRegistry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RegistryPath,   # e.g. 'HKLM:\SOFTWARE\Contoso\Secrets'
        [Parameter(Mandatory)][string]$Name,           # e.g. 'SvcPwd'
        [Parameter(Mandatory)][securestring]$MasterPassword,
        [Parameter(ParameterSetName='Plain')][string]$Secret,
        [Parameter(ParameterSetName='Secure')][securestring]$SecretSecure,
        [int]$Iterations = 200000
    )
    if (-not (Test-Path $RegistryPath)) {
        New-Item -Path $RegistryPath -Force | Out-Null
    }
    $blob = if ($PSCmdlet.ParameterSetName -eq 'Plain') {
        Protect-SecretWithPassword -MasterPassword $MasterPassword -Secret $Secret -Iterations $Iterations
    } else {
        Protect-SecretWithPassword -MasterPassword $MasterPassword -SecretSecure $SecretSecure -Iterations $Iterations
    }
    New-ItemProperty -Path $RegistryPath -Name $Name -Value $blob -PropertyType String -Force | Out-Null
    return $true
}

function Get-EncryptedSecretRegistry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RegistryPath,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][securestring]$MasterPassword,
        [switch]$AsPlainText
    )
    $prop = Get-ItemProperty -Path $RegistryPath -ErrorAction Stop
    $blob = $prop.$Name
    if (-not $blob) { throw "Kein Eintrag '$Name' unter '$RegistryPath' gefunden." }
    return Unprotect-SecretWithPassword -MasterPassword $MasterPassword -ProtectedBlobBase64 $blob -AsPlainText:$AsPlainText
}

# -----------------------------
# Beispiel: Nutzung
# -----------------------------
# 1) Secret erzeugen & in Registry speichern (HKCU-Beispiel)
# $mp = Read-Host "Master-Passwort (Erstellen)" -AsSecureString
# $svc = Read-Host "Service-Passwort (Klartext)" -AsSecureString
# Set-EncryptedSecretRegistry -RegistryPath 'HKCU:\SOFTWARE\Contoso\Secrets' -Name 'SvcPwd' -MasterPassword $mp -SecretSecure $svc

# 2) Secret später lesen & entschlüsseln
# $mp2 = Read-Host "Master-Passwort (Lesen)" -AsSecureString
# $pwSecure = Get-EncryptedSecretRegistry -RegistryPath 'HKCU:\SOFTWARE\Contoso\Secrets' -Name 'SvcPwd' -MasterPassword $mp2
# $cred = New-Object System.Management.Automation.PSCredential ("user@domain.tld", $pwSecure)