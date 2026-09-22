; Inno Setup script for the formal Windows release.
; Build with:
;   iscc.exe /DStagingDir=<absolute staging directory> /DOutputDir=<absolute output directory> HandwritingOCR.iss

#ifndef StagingDir
  #define StagingDir "..\\release\\HandwritingOCR"
#endif
#ifndef OutputDir
  #define OutputDir "..\\release\\installer"
#endif

#define AppVersion "1.0.0"

[Setup]
AppId={{A8B8DA5A-0D7B-4A0B-9DD9-5C9A50F7C2B2}
AppName=手稿 · 手写中文文章数字化工具
AppVersion={#AppVersion}
AppPublisher=HandwritingOCR
DefaultDirName={localappdata}\Programs\HandwritingOCR
DefaultGroupName=手稿
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=HandwritingOCR-Setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName=手稿 · 手写中文文章数字化工具

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加快捷方式："; Flags: unchecked

[Files]
Source: "{#StagingDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\手稿"; Filename: "{app}\release-launch.bat"; WorkingDir: "{app}"
Name: "{group}\发布环境诊断"; Filename: "{app}\diagnose-release.bat"; WorkingDir: "{app}"
Name: "{autodesktop}\手稿"; Filename: "{app}\release-launch.bat"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "正在安装 Microsoft Visual C++ 运行库..."; Flags: waituntilterminated runhidden; Check: NeedVCRedist
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""HandwritingOCR LAN Upload"" dir=in action=allow protocol=TCP localport=18765 profile=private,domain"; StatusMsg: "正在配置局域网上传权限..."; Flags: waituntilterminated runhidden
Filename: "{app}\release-launch.bat"; WorkingDir: "{app}"; Description: "启动手稿"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""HandwritingOCR LAN Upload"""; Flags: waituntilterminated runhidden

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
function NeedVCRedist(): Boolean;
begin
  Result := not (RegKeyExists(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64') or
                 RegKeyExists(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'));
end;
