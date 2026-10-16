param(
    [ValidateSet('Debug','Release','Sürüm')][string]$Configuration='Release',
    [string]$MsBuildPath,
    [string]$InnoPath
)
$ErrorActionPreference='Stop'

function Invoke-ReleaseTool {
    param([string]$Tool,[string[]]$Arguments)
    & $Tool @Arguments
    if($LASTEXITCODE -ne 0){throw "Release tool failed: $Tool (exit $LASTEXITCODE)"}
}

function Invoke-ScreenCaptureRelease {
    <# İki mimarinin görüntü/ses DLL'lerini üretir. Sürüm link imzası hata verirse
       setup üretilmez; Inno aynı araçla setup ve kaldırıcıyı da zaman damgalı imzalar. #>
    param([string]$Configuration,[string]$MsBuildPath,[string]$InnoPath)
    $root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    foreach($platform in @('Win32','x64')){
        foreach($project in @('ScreenCapture','AudioCapture')){
            Invoke-ReleaseTool -Tool $MsBuildPath -Arguments @((Join-Path $root "build/$project.vcxproj"),'/t:Build','/nologo','/v:minimal',"/p:Configuration=$Configuration","/p:Platform=$platform")
        }
    }
    $innoArguments=@("/DConfiguration=$Configuration",(Join-Path $root 'installer/CTCOMM.iss'))
    if($Configuration -eq 'Sürüm'){
        $signer=Join-Path $root 'tools/signing/Sign-InnoArtifact.ps1'
        $innoArguments=@('/DSigned',('/Sctcomm=powershell.exe -NoProfile -NonInteractive -File $q'+$signer+'$q -Path $f'))+$innoArguments
    }
    Invoke-ReleaseTool -Tool $InnoPath -Arguments $innoArguments
}

if($MyInvocation.InvocationName -ne '.'){
    if(!$MsBuildPath){
        $vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
        $MsBuildPath=(& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1)
    }
    if(!$InnoPath){
        $candidates=@((Join-Path $PSScriptRoot '../.tools/InnoSetup/ISCC.exe'),"${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe","$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe")
        $InnoPath=$candidates | Where-Object {Test-Path -LiteralPath $_} | Select-Object -First 1
    }
    if(!$MsBuildPath -or !$InnoPath){throw 'Install Visual C++ Build Tools and Inno Setup 6; or provide -MsBuildPath and -InnoPath.'}
    if($Configuration -eq 'Sürüm'){
        foreach($name in @('CTCOMM_SIGNING_THUMBPRINT','CTCOMM_SMCTL_PATH','CTCOMM_SIGNING_KEYPAIR_ALIAS')){
            if(![Environment]::GetEnvironmentVariable($name,'Process')){[Environment]::SetEnvironmentVariable($name,[Environment]::GetEnvironmentVariable($name,'User'),'Process')}
        }
        & (Join-Path $PSScriptRoot 'signing/Setup-Signing.ps1') -CheckOnly
    }
    Invoke-ScreenCaptureRelease -Configuration $Configuration -MsBuildPath $MsBuildPath -InnoPath $InnoPath
}
