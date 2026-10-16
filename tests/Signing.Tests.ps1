Describe 'Native signed configuration' {
    It 'signs only Sürüm before packaging: <configuration>' -TestCases @(@{configuration='Release';expected='unsigned'},@{configuration='Debug';expected='unsigned'},@{configuration='Sürüm';expected='signed'}) {
        param($configuration,$expected)
        $target=Join-Path (Split-Path $PSScriptRoot) 'Directory.Build.targets'
        $root=New-Item -ItemType Directory -Path (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
        $file=Join-Path $root 'product.dll'; $signer=Join-Path $root 'sign.ps1'; $project=Join-Path $root 'fixture.proj'
        Set-Content $signer 'param($Path,$Thumbprint) Set-Content $Path signed'
        @"
<Project><PropertyGroup><ConfigurationType>DynamicLibrary</ConfigurationType><TargetPath>$file</TargetPath><CtcommSigningScript>$signer</CtcommSigningScript><CtcommSigningThumbprint>$('A'*40)</CtcommSigningThumbprint></PropertyGroup><Import Project="$target" Condition="Exists('$target')"/><Target Name="Link"><WriteLinesToFile File="$file" Lines="unsigned" Overwrite="true"/></Target><Target Name="Build" DependsOnTargets="Link"/></Project>
"@ | Set-Content $project
        & dotnet msbuild $project /t:Build /nologo /v:quiet "/p:Configuration=$configuration"
        $LASTEXITCODE | Should -Be 0
        (Get-Content $file -Raw).Trim() | Should -Be $expected
    }
}
