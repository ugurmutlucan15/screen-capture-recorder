BeforeAll {
    $scriptPath=Join-Path (Split-Path $PSScriptRoot) 'tools/Build-Release.ps1'
    if(Test-Path $scriptPath){. $scriptPath}else{function Invoke-ScreenCaptureRelease {throw 'Release orchestration is not implemented'};function Invoke-ReleaseTool{}}
}
Describe 'Setup build orchestration' {
    BeforeEach { Mock Invoke-ReleaseTool {} }
    It 'builds both architectures before compiling signed setup' {
        Invoke-ScreenCaptureRelease -Configuration 'Sürüm' -MsBuildPath 'msbuild.exe' -InnoPath 'ISCC.exe'
        Should -Invoke Invoke-ReleaseTool -Times 4 -ParameterFilter {$Tool -eq 'msbuild.exe' -and $Arguments -contains '/p:Configuration=Sürüm'}
        Should -Invoke Invoke-ReleaseTool -Times 1 -ParameterFilter {$Tool -eq 'ISCC.exe' -and $Arguments -contains '/DSigned'}
    }
    It 'keeps Release setup unsigned' {
        Invoke-ScreenCaptureRelease -Configuration Release -MsBuildPath 'msbuild.exe' -InnoPath 'ISCC.exe'
        Should -Invoke Invoke-ReleaseTool -Times 1 -ParameterFilter {$Tool -eq 'ISCC.exe' -and $Arguments -notcontains '/DSigned'}
    }
    It 'does not create setup after a failed native build or signature' {
        Mock Invoke-ReleaseTool {throw 'Native signing failed'} -ParameterFilter {$Tool -eq 'msbuild.exe'}
        {Invoke-ScreenCaptureRelease -Configuration 'Sürüm' -MsBuildPath 'msbuild.exe' -InnoPath 'ISCC.exe'} | Should -Throw '*failed*'
        Should -Invoke Invoke-ReleaseTool -Times 0 -ParameterFilter {$Tool -eq 'ISCC.exe'}
    }
}
