[Setup]
AppName=EduSync
AppVersion=1.0.0
AppPublisher=EduSync Team
DefaultDirName={autopf}\EduSync
DefaultGroupName=EduSync
OutputDir=.
OutputBaseFilename=EduSync-Setup
Compression=lzma
SolidCompression=yes
UninstallDisplayIcon={app}\quiz_app.exe

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\EduSync"; Filename: "{app}\quiz_app.exe"
Name: "{commondesktop}\EduSync"; Filename: "{app}\quiz_app.exe"

[Run]
Filename: "{app}\quiz_app.exe"; Description: "Launch EduSync"; Flags: nowait postinstall skipifsilent
