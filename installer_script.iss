; ==============================================================================
; Inno Setup Script: نظام إدارة محطة الوقود - Pro
; Fuel Station Management System Pro - Windows Single Installer
; ==============================================================================

#ifndef MyAppVersion
#define MyAppVersion "3"
#endif

#define MyAppName "نظام إدارة محطة الوقود - Pro"
#define MyAppEnglishName "FuelStationAppPro"
#define MyAppPublisher "Alrafeaalimam"
#define MyAppExeName "fuel_station_app_pro.exe"

[Setup]
; App Identity
AppId={{C6D2B7E1-84E3-4E90-B8A9-68FC23A1B14E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppCopyright=Copyright (C) 2026 {#MyAppPublisher}

; Installation Paths
DefaultDirName={autopf}\{#MyAppEnglishName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; 64-bit Architecture for Flutter Windows x64
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Visual & UI Configuration
OutputDir=installer_output
OutputBaseFilename=FuelStationAppPro-Setup-v{#MyAppVersion}
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=115
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

; Uninstall registration in Windows Programs & Features
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
CreateUninstallRegKey=yes

[Languages]
Name: "arabic"; MessagesFile: "windows\installer\Arabic.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
; Package all release artifacts: executable, flutter dlls, sqlite3.dll, printing dlls, data folder
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// رسالة تنبيه أثناء إلغاء التثبيت تؤكد للمستخدم أن قاعدة البيانات لم ولن تُحذف
function InitializeUninstall(): Boolean;
begin
  Result := True;
  MsgBox(
    'تنبيه أمني هام لحماية بيانات محطة الوقود:' #13#10 #13#10 +
    'سيتم الآن إلغاء تثبيت ملفات البرنامج فقط.' #13#10 #13#10 +
    'يرجى الاطمئنان بأن قاعدة بيانات المحطة (fuel_station_pro.db) وسجلات المبيعات والورديات والترخيص ' +
    'لن يتم حذفها نهائياً، وذلك ضماناً لسلامة كافة حساباتكم المالية.' #13#10 #13#10 +
    '(Notice: Database fuel_station_pro.db and license records are safely preserved).',
    mbInformation, MB_OK);
end;
