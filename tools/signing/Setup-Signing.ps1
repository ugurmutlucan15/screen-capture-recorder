param([switch]$Install, [switch]$CheckOnly)
$ErrorActionPreference='Stop'
# MSBuild alt oturumunda da Cert: sağlayıcısı kullanılabilir olmalıdır.
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Security/Microsoft.PowerShell.Security.psd1') -ErrorAction Stop

function Get-CtcommSigningSettings {
    <# Her PC'de aynı açık sertifika ve HSM anahtarını, o kullanıcının ONE Clients
       kurulumuyla bağlar. Sürüm/yol makineye özeldir; hiçbir sır Git'ten okunmaz. #>
    param([string]$UserProfile=$env:USERPROFILE)
    $root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
    $config=Get-Content (Join-Path $PSScriptRoot 'signing.json') -Raw | ConvertFrom-Json
    $certificate=[Security.Cryptography.X509Certificates.X509Certificate2]::new((Join-Path $root $config.certificate))
    $tools=@(Get-ChildItem -Path (Join-Path $UserProfile '.digicert-ucpc/applications/klsmctl/*/smctl.exe') -ErrorAction SilentlyContinue)
    $tool=$tools | Where-Object { $_.Directory.Name -match '^\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Directory.Name } -Descending | Select-Object -First 1
    if (-not $tool) { throw 'Open DigiCert ONE Clients, sign in and install SMCTL; then run Setup-Signing.ps1 again.' }
    [pscustomobject]@{Thumbprint=$certificate.Thumbprint;KeypairAlias=$config.keypairAlias;SigningManagerPath=$tool.FullName}
}

function Install-CtcommSigningPackage {
    param([string]$Url,[string]$FileName,[switch]$Msi)
    $folder=Join-Path $env:LOCALAPPDATA 'CTCOMM/signing-installers'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $file=Join-Path $folder $FileName
    Invoke-WebRequest -Uri $Url -OutFile $file
    $signature=Get-AuthenticodeSignature -LiteralPath $file
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'DigiCert') { throw 'DigiCert installer signature validation failed.' }
    if ($Msi) {
        $process=Start-Process msiexec.exe -Verb RunAs -ArgumentList @('/i',('"'+$file+'"'),'/qn','/norestart') -Wait -PassThru
    }
    else { $process=Start-Process -FilePath $file -Wait -PassThru }
    if ($process.ExitCode -notin @(0,3010)) { throw "DigiCert installer failed (exit $($process.ExitCode))." }
}

if ($MyInvocation.InvocationName -ne '.') {
    if ($Install -and -not $CheckOnly) {
        if (-not (Test-Path 'C:\Program Files\DigiCert\DigiCert Keylocker Tools\smctl.exe')) {
            Install-CtcommSigningPackage -Url 'https://pki-downloads.digicert.com/stm/latest/Keylockertools-windows-x64.msi' -FileName 'Keylockertools-windows-x64.msi' -Msi
        }
        $clientTools=@(Get-ChildItem -Path "$env:USERPROFILE\.digicert-ucpc\applications\klsmctl\*\smctl.exe" -ErrorAction SilentlyContinue)
        if (-not $clientTools.Count) {
            Install-CtcommSigningPackage -Url 'https://pki-downloads.digicert.com/stm/latest/DigiCert-ONE-Clients-1.9.0-win-x64.exe' -FileName 'DigiCert-ONE-Clients-1.9.0-win-x64.exe'
            throw 'Complete ONE Clients sign-in/MFA and install SMCTL in the app, then run this command again. No new code signing key is needed.'
        }
    }
    $settings=Get-CtcommSigningSettings
    # Healthcheck'in tamamı sır içerebilir; yalnız bağlantı durumunu raporla.
    $health=(& $settings.SigningManagerPath healthcheck --dynamic-auth 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or $health -notmatch '(?m)^Status: Connected\s*$') { throw 'Sign in to DigiCert ONE Clients; connected KeyLocker credentials are required.' }
    if (-not $CheckOnly) {
        & $settings.SigningManagerPath windows certsync --dynamic-auth --keypair-alias=$($settings.KeypairAlias)
        if ($LASTEXITCODE -ne 0) { throw 'KeyLocker certificate sync failed.' }
    }
    $cert=Get-Item -LiteralPath "Cert:\CurrentUser\My\$($settings.Thumbprint)" -ErrorAction Stop
    if (-not $cert.HasPrivateKey -or $cert.NotAfter -le (Get-Date)) { throw 'A current KeyLocker certificate with private-key association is required.' }
    if (-not $CheckOnly) {
        [Environment]::SetEnvironmentVariable('CTCOMM_SIGNING_THUMBPRINT',$settings.Thumbprint,'User')
        [Environment]::SetEnvironmentVariable('CTCOMM_SIGNING_KEYPAIR_ALIAS',$settings.KeypairAlias,'User')
        [Environment]::SetEnvironmentVariable('CTCOMM_SMCTL_PATH',$settings.SigningManagerPath,'User')
        [Environment]::SetEnvironmentVariable('CTCOMM_SIGNING_ENABLED','true','User')
    }
    Write-Host 'CTCOMM signing is ready. Restart Visual Studio after initial setup. The same cloud signing key is used on every authorized PC.'
}
