#ifndef AppVersion
#define AppVersion "0.0.0"
#endif

[Setup]
AppId={{4C8A9F6D-D53A-4BCB-8F37-6DB3AFD24D8A}}
AppName=Strumok
AppVersion={#AppVersion}
AppPublisher=Strumok
DefaultDirName={autopf}\Strumok
DefaultGroupName=Strumok
OutputBaseFilename=StrumokSetup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\strumok.exe

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Strumok"; Filename: "{app}\strumok.exe"
Name: "{autodesktop}\Strumok"; Filename: "{app}\strumok.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\strumok.exe"; Description: "Launch Strumok"; Flags: nowait postinstall skipifsilent
