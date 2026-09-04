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

  ; 卸载器
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\WezTerm4Neil" "InstallDir" "$INSTDIR"

  DetailPrint "安装完成：WezTerm4Neil ${APP_VERSION}"
  DetailPrint "安装目录: $INSTDIR"
  DetailPrint "配置已写入 %USERPROFILE%\.config（wezterm / fish / starship）"
SectionEnd

; ---- 卸载区段 ----------------------------------------------------------------
Section "Uninstall"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKCU "Software\WezTerm4Neil"
  ; 注意：不删除 ~/.config 下的用户配置（保留用户数据）
  DetailPrint "已卸载程序；如需删除配置请手动删除 %USERPROFILE%\.config\wezterm 等目录"
SectionEnd
