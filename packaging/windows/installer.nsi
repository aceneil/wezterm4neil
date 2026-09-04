; ============================================================================
; WezTerm4Neil · Windows 安装器 (NSIS)
; ----------------------------------------------------------------------------
; 编译（由 .github/workflows/release.yml 的 build-windows job 调用）:
;   makensis /DSOURCE_DIR=<payload绝对路径> /DAPP_VERSION=<版本> /DOUT_FILE=<输出.exe> installer.nsi
; payload 目录内容 = 便携 WezTerm\ + starship.exe + wezterm.lua/config.fish/starship.toml
;                   + install.ps1 + README.txt + VERSIONS.txt + licenses\
; 安装行为：解包到 %LOCALAPPDATA%\Programs\wezterm4neil → 调用随包 install.ps1
;           （脚本检测到已在安装目录内运行会跳过程序复制，仅注册 PATH + 落 ~/.config 配置）
; ============================================================================

Unicode true
!include "LogicLib.nsh"
RequestExecutionLevel user        ; 不需要管理员（用户级安装）
SetShellVarContext current        ; 快捷方式/卸载注册走当前用户（无需管理员）
SetCompressor /SOLID lzma

Name "WezTerm4Neil ${APP_VERSION}"
OutFile "${OUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\wezterm4neil"
InstallDirRegKey HKCU "Software\WezTerm4Neil" "InstallDir"

; ---- 页面 --------------------------------------------------------------------
Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

; ---- 安装区段 ----------------------------------------------------------------
Section "Install"
  SetOutPath "$INSTDIR"
  ; 递归打入整个 payload
  File /r "${SOURCE_DIR}\*.*"

  ; 部署：注册用户 PATH + 写入 ~/.config（install.ps1 会检测 Root==AppDir 而跳过程序复制）
  nsExec::ExecToStack 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\install.ps1"'
  Pop $0
  ${If} $0 != "0"
    DetailPrint "install.ps1 返回非零($0)，配置部署可能未完成；可手动运行: powershell -ExecutionPolicy Bypass -File '$INSTDIR\install.ps1'"
  ${EndIf}

  ; 卸载器 + 系统“添加或删除程序”入口 + 快捷方式
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\WezTerm4Neil" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\WezTerm4Neil" "DisplayName" "WezTerm4Neil ${APP_VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\WezTerm4Neil" "DisplayIcon" "$INSTDIR\WezTerm\wezterm-gui.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\WezTerm4Neil" "UninstallString" "$\"$INSTDIR\Uninstall.exe$\""
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\WezTerm4Neil" "Publisher" "aceneil"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\WezTerm4Neil" "DisplayVersion" "${APP_VERSION}"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\WezTerm4Neil" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\WezTerm4Neil" "NoRepair" 1

  ; 开始菜单 + 桌面快捷方式（指向随包 WezTerm GUI）
  CreateDirectory "$SMPROGRAMS\WezTerm4Neil"
  CreateShortCut "$SMPROGRAMS\WezTerm4Neil\WezTerm4Neil.lnk" "$INSTDIR\WezTerm\wezterm-gui.exe" "" "$INSTDIR\WezTerm\wezterm-gui.exe"
  CreateShortCut "$DESKTOP\WezTerm4Neil.lnk" "$INSTDIR\WezTerm\wezterm-gui.exe" "" "$INSTDIR\WezTerm\wezterm-gui.exe"

  DetailPrint "安装完成：WezTerm4Neil ${APP_VERSION}"
  DetailPrint "安装目录: $INSTDIR"
  DetailPrint "已创建开始菜单与桌面快捷方式；可在『设置→应用→已安装的应用』中卸载"
  DetailPrint "配置已写入 %USERPROFILE%\.config（wezterm / starship）+ Nu 自动加载"
SectionEnd

; ---- 卸载区段 ----------------------------------------------------------------
Section "Uninstall"
  ; 快捷方式与注册表清理
  Delete "$DESKTOP\WezTerm4Neil.lnk"
  Delete "$SMPROGRAMS\WezTerm4Neil\WezTerm4Neil.lnk"
  RMDir "$SMPROGRAMS\WezTerm4Neil"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\WezTerm4Neil"

  Delete "$INSTDIR\Uninstall.exe"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKCU "Software\WezTerm4Neil"
  ; 注意：不删除 ~/.config 与 Nu autoload 下的用户配置（保留用户数据）
  DetailPrint "已卸载程序；如需删除配置请手动删除 %USERPROFILE%\.config\wezterm 等目录"
SectionEnd
