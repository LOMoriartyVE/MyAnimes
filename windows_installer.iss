; Inno Setup Script for MyAnimes Flutter Application
; Download Inno Setup from: https://jrsoftware.org/isdl.php

[Setup]
AppId={{C78A4B67-5A58-4EE9-9138-1E7E369CEB2B}
AppName=MyAnimes
AppVersion=1.1.70
AppPublisher=LOMoriartyVE
AppPublisherURL=https://github.com/LOMoriartyVE/MyAnimes
AppSupportURL=https://github.com/LOMoriartyVE/MyAnimes/issues
AppUpdatesURL=https://github.com/LOMoriartyVE/MyAnimes/releases
DefaultDirName={autopf}\MyAnimes
DefaultGroupName=MyAnimes
DisableProgramGroupPage=yes
; Place output installer in the build folder
OutputDir=build\windows\installer
OutputBaseFilename=MyAnimes-Setup-1.1.70
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Copy all compiled binaries and assets from Flutter release build folder
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\MyAnimes"; Filename: "{app}\my_animes.exe"
Name: "{autodesktop}\MyAnimes"; Filename: "{app}\my_animes.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\my_animes.exe"; Description: "{cm:LaunchProgram,MyAnimes}"; Flags: nowait postinstall skipifsilent
