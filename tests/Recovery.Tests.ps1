Describe 'Recovery under native MSBuild' {
    It 'loads the certificate provider before checking the user certificate' {
        $root=Split-Path $PSScriptRoot
        $setup=Join-Path $root 'tools/signing/Setup-Signing.ps1'
        $project=Join-Path $TestDrive 'provider.proj'
        $command="powershell.exe -NoProfile -Command `". '$setup'; Get-Item Cert:\CurrentUser\My\FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF -ErrorAction Stop`""
        $escaped=[Security.SecurityElement]::Escape($command)
        "<Project><Target Name=`"Build`"><Exec Command=`"$escaped`" /></Target></Project>" | Set-Content $project
        $output=(& 'C:/Program Files (x86)/Microsoft Visual Studio/18/BuildTools/MSBuild/Current/Bin/MSBuild.exe' $project /nologo /v:minimal 2>&1 | Out-String)
        $output | Should -Not -Match 'DriveNotFound'
        $output | Should -Match 'PathNotFound'
    }
}
