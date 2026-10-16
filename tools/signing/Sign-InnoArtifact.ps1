param([Alias('Path')][string]$ArtifactPath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Sign-Artifact.ps1')

function Invoke-InnoSigning {
    <# Inno kaldırıcıyı .e32.tmp olarak verir. İmzacıya yalnız EXE kopyası gönderilir;
       doğrulama bitmeden orijinal değişmez, hata halinde yalnız bize ait kopya temizlenir. #>
    param([string]$Path)
    $file=Get-Item -LiteralPath $Path
    $signPath=$file.FullName
    $copy=$null
    if($file.Extension -ne '.exe'){
        if($file.Name -notmatch '\.e(32|64)\.tmp$' -or $file.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Unsupported Inno artifact.'}
        $bytes=[IO.File]::ReadAllBytes($file.FullName)
        if($bytes.Length -lt 2 -or $bytes[0] -ne 77 -or $bytes[1] -ne 90){throw 'Inno artifact must be a PE executable.'}
        $signPath=$file.FullName+'.signing.exe'
        [IO.File]::Copy($file.FullName,$signPath,$false)
        $copy=$signPath
    }
    try {
        Invoke-CtcommArtifactSigning -Path $signPath -Thumbprint $env:CTCOMM_SIGNING_THUMBPRINT -SigningManagerPath $env:CTCOMM_SMCTL_PATH -KeypairAlias $env:CTCOMM_SIGNING_KEYPAIR_ALIAS
        if($copy){[IO.File]::Copy($copy,$file.FullName,$true)}
    }
    finally {
        if($copy -and (Test-Path -LiteralPath $copy)){
            $item=Get-Item -LiteralPath $copy
            if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Refusing to remove a reparse point.'}
            Remove-Item -LiteralPath $copy
        }
    }
}
if($MyInvocation.InvocationName -ne '.') { Invoke-InnoSigning -Path $ArtifactPath }
