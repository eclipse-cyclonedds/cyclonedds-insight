; The real version will be passed by command-line call
#ifndef TheAppVersion
#define TheAppVersion "unknown"
#endif

#define TheAppName "CycloneDDS Insight"
#define TheAppPublisher "Eclipse Cyclone DDS"
#define TheAppURL "https://cyclonedds.io/"
#define TheAppExeName "CycloneDDS Insight.exe"
#define TheAppAssocName "Interface Definition File"
#define TheAppAssocExt ".idl"
#define TheAppAssocKey StringChange(TheAppAssocName, " ", "") + TheAppAssocExt

[Setup]
AppId={{FC901B87-B2DD-4DB7-B317-ADA9B708841F}
AppName={#TheAppName}
AppVersion={#TheAppVersion}
VersionInfoVersion={#TheAppVersion}
AppVerName={#TheAppName} Version {#TheAppVersion}
AppPublisher={#TheAppPublisher}
AppPublisherURL={#TheAppURL}
AppSupportURL={#TheAppURL}
AppUpdatesURL={#TheAppURL}
DefaultDirName={autopf}\{#TheAppName}
ChangesAssociations=yes
DisableProgramGroupPage=yes
LicenseFile=LICENSE
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=dist
OutputBaseFilename=cyclonedds-insight-{#TheAppVersion}-windows-x64
SetupIconFile=res\images\cyclonedds.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "dist\CycloneDDS Insight\{#TheAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "dist\CycloneDDS Insight\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Registry]
Root: HKA; Subkey: "Software\Classes\{#TheAppAssocExt}\OpenWithProgids"; ValueType: string; ValueName: "{#TheAppAssocKey}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\{#TheAppAssocKey}"; ValueType: string; ValueName: ""; ValueData: "{#TheAppAssocName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\{#TheAppAssocKey}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#TheAppExeName},0"
Root: HKA; Subkey: "Software\Classes\{#TheAppAssocKey}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#TheAppExeName}"" ""%1"""
Root: HKA; Subkey: "Software\Classes\Applications\{#TheAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".Thep"; ValueData: ""

[Icons]
Name: "{autoprograms}\{#TheAppName}"; Filename: "{app}\{#TheAppExeName}"
Name: "{autodesktop}\{#TheAppName}"; Filename: "{app}\{#TheAppExeName}"; Tasks: desktopicon

[Run]
; For normal installs (checkbox on finished page)
Filename: "{app}\{#TheAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(TheAppName, '&', '&&')}}"; Flags: nowait runasoriginaluser postinstall skipifsilent

; For silent installs (run automatically)
Filename: "{app}\{#TheAppExeName}"; Flags: nowait runasoriginaluser shellexec skipifnotsilent
