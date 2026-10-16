#ifndef Configuration
#define Configuration "Release"
#endif
#define ProductVersion "0.13.3"
[Setup]
AppId={{1C6BC6CA-2708-49AF-B5F4-1D20385A1B51}
AppName=CTCOMM Screen Capture Recorder
AppVersion={#ProductVersion}
AppPublisher=CTCOMM İletişim Teknolojileri ve Danışmanlık Hiz. Tic. Ltd. Şti.
DefaultDirName={autopf}\CTCOMM\ScreenCaptureRecorder
DefaultGroupName=CTCOMM Screen Capture Recorder
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\artifacts\{#Configuration}\setup
OutputBaseFilename=CTCOMM-ScreenCaptureRecorder-{#ProductVersion}-Setup
Compression=lzma2
SolidCompression=yes
#ifdef Signed
SignTool=ctcomm
SignedUninstaller=yes
SignedUninstallerDir=..\artifacts\{#Configuration}\setup-signed
#else
SignedUninstaller=no
#endif
[Files]
Source: "..\artifacts\{#Configuration}\Win32\screen-capture-recorder.dll"; DestDir: "{app}"; Flags: regserver 32bit restartreplace uninsrestartdelete
Source: "..\artifacts\{#Configuration}\x64\screen-capture-recorder-x64.dll"; DestDir: "{app}"; Flags: regserver 64bit restartreplace uninsrestartdelete; Check: IsWin64
Source: "..\artifacts\{#Configuration}\Win32\audio_sniffer.dll"; DestDir: "{app}"; Flags: regserver 32bit restartreplace uninsrestartdelete
Source: "..\artifacts\{#Configuration}\x64\audio_sniffer-x64.dll"; DestDir: "{app}"; Flags: regserver 64bit restartreplace uninsrestartdelete; Check: IsWin64
Source: "..\LICENSE"; DestDir: "{app}"; DestName: "SCREEN-CAPTURE-LICENSE.txt"
Source: "..\vendor\virtual-audio\LICENSE"; DestDir: "{app}"; DestName: "AUDIO-CAPTURE-LICENSE.txt"
Source: "..\README.adoc"; DestDir: "{app}"

Source: "..\vendor\windows-classic-samples\LICENSE"; DestDir: "{app}"; DestName: "MICROSOFT-SAMPLES-LICENSE.txt"
Source: "..\BUILD-CTCOMM.md"; DestDir: "{app}"
