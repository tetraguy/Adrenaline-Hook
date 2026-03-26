; Adrenaline Hook - Inno Setup Script
; Requires Inno Setup 6.x  https://jrsoftware.org/isinfo.php
; Build:  iscc installer\AdrenalineHook.iss   (from repo root)

#define AppName      "Adrenaline Hook"
#define AppVersion   "2.0.0"
#define AppPublisher "tetraguy"
#define AppURL       "https://github.com/tetraguy/Adrenaline-Hook"
#define AppExeName   "AdrenalineHook.exe"
#define PublishDir   "..\publish\win-x64"

[Setup]
AppId={{8F3A2B1C-4D5E-6F7A-8B9C-0D1E2F3A4B5C}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/issues
AppUpdatesURL={#AppURL}/releases
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
; Output
OutputDir=..\dist
OutputBaseFilename=AdrenalineHook-v{#AppVersion}-x64-Setup
SetupIconFile=..\AdrenalineHookWpf\Adrenaline Hook.ico
Compression=lzma2/ultra64
SolidCompression=yes
; x64 only
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Require Windows 10 1903+
MinVersion=10.0.18362
; Privileges
PrivilegesRequired=lowest
; Misc
WizardStyle=modern
UninstallDisplayIcon={app}\{#AppExeName}
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Installer
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main executable (self-contained single-file, no runtime required)
Source: "{#PublishDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}";       Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Remove log file written by the app on uninstall
Type: files;      Name: "{localappdata}\TetraDev\AdrenalineHookWpf\log.txt"
Type: dirifempty; Name: "{localappdata}\TetraDev\AdrenalineHookWpf"
Type: dirifempty; Name: "{localappdata}\TetraDev"
