BeforeAll {
    $path=Join-Path (Split-Path $PSScriptRoot) 'tools/signing/Sign-InnoArtifact.ps1'
    if(Test-Path $path){. $path}else{function Invoke-InnoSigning {throw 'Inno signing is not implemented'};function Invoke-CtcommArtifactSigning{}}
}
Describe 'Inno uninstaller signing' {
    It 'signs a temporary executable and copies back only the signed bytes' {
        $file=Join-Path $TestDrive 'uninst.e32.tmp'; [IO.File]::WriteAllBytes($file,[byte[]](77,90,0,0))
        Mock Invoke-CtcommArtifactSigning { [IO.File]::WriteAllBytes($Path,[byte[]](77,90,1,2)) }
        Invoke-InnoSigning -Path $file
        [IO.File]::ReadAllBytes($file) | Should -Be @(77,90,1,2)
        Test-Path ($file+'.signing.exe') | Should -BeFalse
    }
    It 'preserves the original when signing fails' {
        $file=Join-Path $TestDrive 'uninst.e32.tmp'; [IO.File]::WriteAllBytes($file,[byte[]](77,90,0,0))
        Mock Invoke-CtcommArtifactSigning {throw 'Signing failed'}
        {Invoke-InnoSigning -Path $file} | Should -Throw '*failed*'
        [IO.File]::ReadAllBytes($file) | Should -Be @(77,90,0,0)
        Test-Path ($file+'.signing.exe') | Should -BeFalse
    }
}
Describe 'Inno command-line argument preservation' {
    It 'passes the input file through the dot-sourced signing library' {
        $file=Join-Path $TestDrive 'uninst.e32.tmp'; Set-Content $file 'not-a-PE'
        $script=Join-Path (Split-Path $PSScriptRoot) 'tools/signing/Sign-InnoArtifact.ps1'
        $output=(& powershell.exe -NoProfile -NonInteractive -File $script -Path $file 2>&1 | Out-String)
        $output | Should -Match 'PE executable'
        $output | Should -Not -Match 'empty string'
    }
}
