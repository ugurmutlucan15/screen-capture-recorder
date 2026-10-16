param(
    [string]$Path,
    [string]$Thumbprint = $env:CTCOMM_SIGNING_THUMBPRINT,
    [string]$SignToolPath,
    [string]$SigningManagerPath = $env:CTCOMM_SMCTL_PATH,
    [string]$KeypairAlias = $env:CTCOMM_SIGNING_KEYPAIR_ALIAS
)
$ErrorActionPreference = 'Stop'
# MSBuild alt oturumunda Cert: sağlayıcısı otomatik yüklenmeyebilir.
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Security/Microsoft.PowerShell.Security.psd1') -ErrorAction Stop

function Invoke-CtcommSignTool {
    param([string]$Tool, [string[]]$Arguments)
    & $Tool @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Native signing failed (exit $LASTEXITCODE)." }
}

function Invoke-CtcommArtifactSigning {
    <#
    Yalnız açıkça seçilen dosyayı KeyLocker'a bağlı kullanıcı sertifikasıyla imzalar.
    Zaman damgası ve yayıncı doğrulanmadan paketleme devam etmez; başka yayıncıya
    ait dosya yeniden imzalanmaz. API anahtarı veya parola bu araca verilmez.
    #>
    param([Parameter(Mandatory)][string]$Path,
          [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{40}$')][string]$Thumbprint,
          [string]$SignToolPath,
          [string]$SigningManagerPath,
          [string]$KeypairAlias)
    $file = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($file.PSIsContainer -or $file.Extension -notin @('.exe','.dll','.msi','.msix')) {
        throw 'Only an explicit EXE, DLL, MSI or MSIX file can be signed.'
    }
    $cert = Get-Item -LiteralPath "Cert:\CurrentUser\My\$Thumbprint" -ErrorAction Stop
    if (-not $cert.HasPrivateKey) { throw 'Certificate private key association is missing; configure KeyLocker and certsync.' }
    if ($cert.NotAfter -le (Get-Date) -or '1.3.6.1.5.5.7.3.3' -notin @($cert.EnhancedKeyUsageList | ForEach-Object {[string]$_.ObjectId})) {
        throw 'A valid Code Signing certificate is required.'
    }
    $signature = Get-AuthenticodeSignature -LiteralPath $file.FullName
    if ($signature.SignerCertificate -and $signature.SignerCertificate.Thumbprint -ne $Thumbprint) {
        throw 'Another publisher already signed this file; preserve the original signature.'
    }
    if ($signature.Status -eq 'Valid' -and $signature.TimeStamperCertificate) {
        Write-Host "Already signed: $($file.FullName)"
        return
    }
    if (-not $SignToolPath) {
        $SignToolPath = Get-ChildItem -Path "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe" -ErrorAction SilentlyContinue |
            Sort-Object { [version]$_.Directory.Parent.Name } -Descending | Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $SignToolPath -or -not (Test-Path -LiteralPath $SignToolPath -PathType Leaf)) { throw 'Windows SDK x64 SignTool is missing.' }
    if ($SigningManagerPath) {
        # ONE Clients mevcut güvenli oturumunu kullanır; build içine sır taşınmaz.
        if (-not (Test-Path -LiteralPath $SigningManagerPath -PathType Leaf)) { throw 'Configured SMCTL path is missing; configure DigiCert ONE Clients.' }
        if (-not $KeypairAlias) { throw 'KeyLocker keypair alias is required for simple signing.' }
        Invoke-CtcommSignTool -Tool $SigningManagerPath -Arguments @('sign','--dynamic-auth','--simple','--keypair-alias',$KeypairAlias,'--fingerprint',$Thumbprint,'--input',$file.FullName,'--digalg','SHA256','--timestamp','--ts-server','http://timestamp.digicert.com')
    }
    else {
        Invoke-CtcommSignTool -Tool $SignToolPath -Arguments @('sign','/sha1',$Thumbprint,'/fd','SHA256','/tr','http://timestamp.digicert.com','/td','SHA256',$file.FullName)
    }
    Invoke-CtcommSignTool -Tool $SignToolPath -Arguments @('verify','/pa','/all','/v',$file.FullName)
    $signed = Get-AuthenticodeSignature -LiteralPath $file.FullName
    if ($signed.Status -ne 'Valid' -or -not $signed.SignerCertificate -or $signed.SignerCertificate.Thumbprint -ne $Thumbprint -or -not $signed.TimeStamperCertificate) {
        throw 'Authenticode verification failed: valid publisher and timestamp are required.'
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Path -or -not $Thumbprint) { throw 'Provide -Path and -Thumbprint (or CTCOMM_SIGNING_THUMBPRINT).' }
    Invoke-CtcommArtifactSigning -Path $Path -Thumbprint $Thumbprint -SignToolPath $SignToolPath -SigningManagerPath $SigningManagerPath -KeypairAlias $KeypairAlias
}
