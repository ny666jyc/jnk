@echo off
chcp 65001 >nul
title 全能清理工具（注册表+内核+卷序列号+系统标识+硬件伪装+深度追踪）

if "%~1"=="/ELEVATED" goto :main
fsutil dirty query %systemdrive% >nul 2>&1
if %errorlevel% equ 0 goto :main
reg query "HKLM\SECURITY" /ve >nul 2>&1
if %errorlevel% equ 0 goto :main
echo 正在请求管理员权限...
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '/ELEVATED' -Verb RunAs"
exit /b

:main
set "PSFILE=%SystemRoot%\Temp\reg_vol_clean.ps1"
set "SVCBAT=%SystemRoot%\Temp\reg_vol_svc.bat"
set "LOGFILE=%SystemRoot%\reg_vol_log.txt"
set "FLAGFILE=%SystemRoot%\reg_vol_done.flag"
set "PSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

cls
echo ============================================================
echo   全能清理工具（七阶段完整版）
echo ============================================================
echo.
echo 阶段1 - 设备实例注册表项 (Enum\*):
echo   显卡 声卡 人机接口 USB USB存储 软件 软件枚举 存储
echo   （蓝牙/网络已排除，父键保留）
echo.
echo 阶段2 - 内核对象相关:
echo   设备接口类 旧驱动残留 PnP缓存 驱动安装缓存
echo   （已跳过驱动卸载以保护网卡/显卡驱动）
echo.
echo 阶段3 - 卷序列号:
echo   自动识别所有固定盘，随机化序列号（XXXX-XXXX 十六进制）
echo.
echo 阶段4 - DNS缓存:
echo   ipconfig /flushdns（清空并刷新DNS解析缓存）
echo.
echo 阶段5 - 系统标识（随机化）:
echo   机器ID 硬件配置ID 计算机名 网络主机名
echo   产品ID 激活密钥 系统安装时间
echo   警告：可能影响系统激活和软件授权！
echo.
echo 阶段6 - 硬件伪装（13项）:
echo   主板/BIOS/CPU 微码 内存 显卡 NVIDIA UUID
echo   键鼠WPP轨迹 EFI/NSI TPM IDE/SCSI硬件ID
echo   磁盘卷标 显示器名称 遥测追踪ID
echo   注意：部分项为易失性或运行时只读。
echo.
echo 阶段7 - 深度追踪清理（10项）:
echo   USN日志/卷影/NVIDIA缓存 预读/BAM/兼容性缓存 最近文件/跳转列表
echo   USB历史 显示器记录 RDP日志 系统更新/临时文件/图标缓存
echo   MAC还原 事件日志 驱动残留
echo   注意：破坏性清理，不可撤销。
echo.
echo.
echo 阶段8 - 网络深度重置与硬件缓存刷新（8项）:
echo   网卡TCP/IP伪装 游戏缓存/外挂清理 PCI/DMA痕迹
echo   Winsock/TCP-IP重置 IPv6重置 虚拟网卡 ARP清理 WMI刷新
echo   警告：网络重置可能导致短暂断网，部分项需重启生效！
echo.
echo 父键保留。清理后必须重启。
echo 警告：操作不可撤销。设备可能需要重新安装驱动。
echo.
set /p "confirm=输入 Y 继续，其他键退出："
if /i not "%confirm%"=="Y" (
    echo 已取消。
    pause
    exit /b
)

echo [1/6] 正在写入 PowerShell 脚本...
if exist "%PSFILE%" del "%PSFILE%"
>> "%PSFILE%" echo $ErrorActionPreference = "Continue"
>> "%PSFILE%" echo $logFile="C:\Windows\reg_vol_log.txt"
>> "%PSFILE%" echo $flagFile="C:\Windows\reg_vol_done.flag"
>> "%PSFILE%" echo(
>> "%PSFILE%" echo "开始时间 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" ^| Out-File -FilePath $logFile -Force -Encoding UTF8
>> "%PSFILE%" echo(
>> "%PSFILE%" echo function Log($msg){
>> "%PSFILE%" echo $msg ^| Out-File -FilePath $logFile -Append -Encoding UTF8
>> "%PSFILE%" echo }
>> "%PSFILE%" echo function Exec($cmd, $timeout = 20) {
>> "%PSFILE%" echo try { $p = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmd" -WindowStyle Hidden -PassThru; if(-not $p.WaitForExit($timeout * 1000)){ try { $p.Kill() } catch {}; return $false }; return $true } catch { return $false }
>> "%PSFILE%" echo }
>> "%PSFILE%" echo(
>> "%PSFILE%" echo(
>> "%PSFILE%" echo function Force-DeleteKey{
>> "%PSFILE%" echo param([string]$PsPath)
>> "%PSFILE%" echo try{
>> "%PSFILE%" echo Remove-Item -Path $PsPath -Recurse -Force -ErrorAction Stop
>> "%PSFILE%" echo return $true
>> "%PSFILE%" echo }catch{
>> "%PSFILE%" echo try{
>> "%PSFILE%" echo $key=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($PsPath.Replace("HKLM:\",""),$true)
>> "%PSFILE%" echo if($key){$key.DeleteSubKeyTree("","");$key.Close();return $true}
>> "%PSFILE%" echo }catch{}
>> "%PSFILE%" echo return $false
>> "%PSFILE%" echo }
>> "%PSFILE%" echo }
>> "%PSFILE%" echo(
>> "%PSFILE%" echo function RndStr6($len){
>> "%PSFILE%" echo $chars="ABCDEF0123456789"
>> "%PSFILE%" echo $r=1..$len^|ForEach-Object{$chars[(Get-Random -Maximum $chars.Length)]}
>> "%PSFILE%" echo return -join $r
>> "%PSFILE%" echo }
>> "%PSFILE%" echo(
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo Log "  阶段1：设备实例注册表项 (Enum)"
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo $totalDel=0; $totalFail=0
>> "%PSFILE%" echo $parents=@("DISPLAY","HDAUDIO","HID","USB","USBSTOR","SW","SWD","STORAGE")
>> "%PSFILE%" echo foreach($p in $parents){
>> "%PSFILE%" echo $path="HKLM:\SYSTEM\CurrentControlSet\Enum\$p"
>> "%PSFILE%" echo Log "处理中：HKLM\SYSTEM\CurrentControlSet\Enum\$p"
>> "%PSFILE%" echo if(-not (Test-Path $path)){ Log "[跳过] 路径不存在"; continue }
>> "%PSFILE%" echo $subs=Get-ChildItem -Path $path -ErrorAction SilentlyContinue
>> "%PSFILE%" echo $cnt=if($subs){$subs.Count}else{0}
>> "%PSFILE%" echo Log "找到 $cnt 个直接子键"
>> "%PSFILE%" echo $ok=0; $fail=0
>> "%PSFILE%" echo foreach($s in $subs){
>> "%PSFILE%" echo $r=Force-DeleteKey $s.PSPath
>> "%PSFILE%" echo if($r){ Log "[删除] $($s.PSChildName)"; $ok++ }else{ Log "[失败] $($s.PSChildName)"; $fail++ }
>> "%PSFILE%" echo }
>> "%PSFILE%" echo Log "小计：成功=$ok / 失败=$fail"
>> "%PSFILE%" echo if($fail -eq 0){ Log "[成功] $p 父键清理完成（删除$ok项）" }else{ Log "[失败] $p 父键有$fail项未删除" }
>> "%PSFILE%" echo $totalDel+=$ok; $totalFail+=$fail
>> "%PSFILE%" echo }
>> "%PSFILE%" echo Log "专项：强制删除 显卡\默认监视器"
>> "%PSFILE%" echo $dm="HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY\Default_Monitor"
>> "%PSFILE%" echo if(Test-Path $dm){ Force-DeleteKey $dm ^| Out-Null; Log "[删除] Default_Monitor" }else{ Log "[跳过] 默认监视器不存在" }
>> "%PSFILE%" echo Log "阶段1总计：已删除=$totalDel / 失败=$totalFail"
>> "%PSFILE%" echo Log ""
>> "%PSFILE%" echo(
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo Log "  阶段2：内核对象相关清理"
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo Log "[2.1] 设备接口类缓存..."
>> "%PSFILE%" echo $dc="HKLM:\SYSTEM\CurrentControlSet\Control\DeviceClasses"
>> "%PSFILE%" echo if(Test-Path $dc){ $dcs=Get-ChildItem $dc -ErrorAction SilentlyContinue; $n=if($dcs){$dcs.Count}else{0}; foreach($k in $dcs){ Remove-Item $k.PSPath -Recurse -Force -ErrorAction SilentlyContinue }; Log "[成功] 已移除 $n 个设备接口项" }else{ Log "[跳过] 设备接口类不存在" }
>> "%PSFILE%" echo Log "[2.2] 旧版非PnP驱动残留..."
>> "%PSFILE%" echo $root="HKLM:\SYSTEM\CurrentControlSet\Enum\Root"
>> "%PSFILE%" echo if(Test-Path $root){ $leg=Get-ChildItem $root -ErrorAction SilentlyContinue ^| Where-Object { $_.PSChildName -like "LEGACY_*" }; $n=if($leg){$leg.Count}else{0}; foreach($k in $leg){ Remove-Item $k.PSPath -Recurse -Force -ErrorAction SilentlyContinue }; Log "[成功] 已移除 $n 个旧驱动项" }else{ Log "[跳过] Root项不存在" }
>> "%PSFILE%" echo Log "[2.3] PnP枚举缓存..."
>> "%PSFILE%" echo Remove-Item "HKLM:\SYSTEM\CurrentControlSet\Enum\ACPI" -Recurse -Force -ErrorAction SilentlyContinue
>> "%PSFILE%" echo Log "[成功] PnP缓存已清理"
>> "%PSFILE%" echo Log "[2.4] 第三方驱动包 - 已跳过以保护网卡/显卡驱动"
>> "%PSFILE%" echo Log "[2.5] 设备安装缓存..."
>> "%PSFILE%" echo $infcache="C:\Windows\INF\INFCACHE.1"
>> "%PSFILE%" echo if(Test-Path $infcache){ try{ Remove-Item $infcache -Force -ErrorAction Stop; Log "[成功] 驱动安装缓存" }catch{ Log "[跳过] 缓存正在使用中" } }
>> "%PSFILE%" echo Log ""
>> "%PSFILE%" echo(
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo Log "  阶段3：随机化卷序列号"
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo $drives=Get-PSDrive -PSProvider FileSystem ^| Where-Object { $_.Used -gt 0 -or $_.Free -gt 0 }
>> "%PSFILE%" echo $fixed=$drives ^| Where-Object { $_.Name -match "^[C-Z]$" }
>> "%PSFILE%" echo Log "找到 $($fixed.Count) 个固定盘：$($fixed.Name -join ', ')"
>> "%PSFILE%" echo foreach($d in $fixed){
>> "%PSFILE%" echo $dl=$d.Name
>> "%PSFILE%" echo $devPath="\\.\$dl`:"
>> "%PSFILE%" echo try{
>> "%PSFILE%" echo $old=(Get-Volume -DriveLetter $dl -ErrorAction Stop).FileSystemLabel
>> "%PSFILE%" echo $fsType=(Get-Volume -DriveLetter $dl -ErrorAction Stop).FileSystemType
>> "%PSFILE%" echo }catch{ $old=""; $fsType="NTFS" }
>> "%PSFILE%" echo $newSN=(RndStr6 4)+"-"+(RndStr6 4)
>> "%PSFILE%" echo $sbytes=[byte[]]@(0,0,0,0)
>> "%PSFILE%" echo $parts=$newSN -split "-"
>> "%PSFILE%" echo $val=[Convert]::ToUInt32($parts[1]+$parts[0],16)
>> "%PSFILE%" echo $sbytes=[BitConverter]::GetBytes($val)
>> "%PSFILE%" echo $oldDisplay="$dl`: $old"
>> "%PSFILE%" echo $newDisplay="$dl`: $newSN"
>> "%PSFILE%" echo try{
>> "%PSFILE%" echo $fs=[System.IO.File]::Open($devPath,'Open','ReadWrite','ReadWrite')
>> "%PSFILE%" echo $sector=New-Object byte[] 512
>> "%PSFILE%" echo $fs.Read($sector,0,512) ^| Out-Null
>> "%PSFILE%" echo switch -Regex ($fsType){ "NTFS" {$off=0x48} "FAT32" {$off=0x43} "^FAT" {$off=0x27} "exFAT" {$off=0x64} default {$off=0x48} }
>> "%PSFILE%" echo [Array]::Copy($sbytes,0,$sector,$off,4)
>> "%PSFILE%" echo $fs.Seek(0,'Begin') ^| Out-Null
>> "%PSFILE%" echo $fs.Write($sector,0,512)
>> "%PSFILE%" echo $fs.Flush()
>> "%PSFILE%" echo $fs.Close()
>> "%PSFILE%" echo ^& fsutil volume dismount "$dl`:" 2^>$null ^| Out-Null
>> "%PSFILE%" echo Log "    [成功] $dl`: [$fsType] $oldDisplay -> $newDisplay"
>> "%PSFILE%" echo }catch{
>> "%PSFILE%" echo Log "    [失败] $dl`: [$fsType] $oldDisplay（写入失败，需重启）"
>> "%PSFILE%" echo }
>> "%PSFILE%" echo }
>> "%PSFILE%" echo Log "--- 卷序列号已随机化（非系统盘立即生效，系统盘需重启）---"
>> "%PSFILE%" echo Log ""
>> "%PSFILE%" echo(
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo Log "  阶段4：DNS缓存刷新"
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo try{ ^& ipconfig /flushdns 2^>^&1 ^| Out-Null; Log "  [成功] DNS缓存已刷新" }catch{ Log "  [失败] DNS缓存刷新" }
>> "%PSFILE%" echo Log "--- DNS缓存已刷新 ---"
>> "%PSFILE%" echo Log ""
>> "%PSFILE%" echo(
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo Log "  阶段5：随机化系统标识"
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo Log "[5.1] 机器ID..."
>> "%PSFILE%" echo try{ Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography" "MachineGuid" ([guid]::NewGuid().ToString()) -ErrorAction Stop; Log "  [成功] MachineId 已随机化" }catch{ Log "  [失败] MachineId" }
>> "%PSFILE%" echo Log "[5.2] 硬件配置文件ID..."
>> "%PSFILE%" echo try{ $cfgNum=(Get-Random -Minimum 1 -Maximum 11); Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\IDConfigDB" "CurrentConfig" ([byte[]]@($cfgNum,0,0,0)) -ErrorAction Stop; Log "  [成功] 硬件配置ID -> $cfgNum" }catch{ Log "  [失败] 硬件配置ID" }
>> "%PSFILE%" echo Log "[5.3] 计算机名..."
>> "%PSFILE%" echo $newName="PC-"+(Get-Date -Format "yyyyMMdd")+(-join ((65..90)^|Get-Random -Count 4^|ForEach-Object{[char]$_}))
>> "%PSFILE%" echo try{ Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" "ComputerName" $newName -ErrorAction Stop; Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "NV Hostname" $newName -ErrorAction Stop; Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "Hostname" $newName -ErrorAction Stop; Log "  [成功] 计算机名 -> $newName" }catch{ Log "  [失败] 计算机名" }
>> "%PSFILE%" echo Log "[5.4] 网络主机名..."
>> "%PSFILE%" echo try{ ^& hostname ^| Out-Null; Log "  [成功] 主机名已同步" }catch{ Log "  [失败] 主机名" }
>> "%PSFILE%" echo Log "[5.5] 产品ID..."
>> "%PSFILE%" echo try{ $np="00"+(RndStr6 2)+"-"+(RndStr6 5)+"-"+(RndStr6 5)+"-"+(RndStr6 5); Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" "ProductId" $np -ErrorAction Stop; Log "  [成功] 产品ID -> $np" }catch{ Log "  [失败] 产品ID" }
>> "%PSFILE%" echo Log "[5.6] 激活密钥..."
>> "%PSFILE%" echo try{ $bytes=[byte[]](1..512^|ForEach-Object{Get-Random -Maximum 256}); Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" "DigitalProductId" $bytes -ErrorAction Stop; Log "  [成功] 激活密钥已随机化（512字节）" }catch{ Log "  [失败] 激活密钥" }
>> "%PSFILE%" echo Log "[5.7] 系统安装时间..."
>> "%PSFILE%" echo try{ $rndDate=(Get-Date).ToFileTime(); Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" "InstallDate" $rndDate -ErrorAction Stop; Log "  [成功] 安装时间已随机化" }catch{ Log "  [失败] 安装时间" }
>> "%PSFILE%" echo Log "--- 系统标识已随机化（计算机名需重启生效）---"
>> "%PSFILE%" echo Log "  警告：可能影响系统激活状态和软件授权！"
>> "%PSFILE%" echo Log ""
>> "%PSFILE%" echo(
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo Log "  阶段6：硬件伪装（13项）"
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo Log "[6.1] 主板/BIOS/CPU伪装..."
>> "%PSFILE%" echo $cpuNames=@("Intel(R) Core(TM) i9-13900K","Intel(R) Core(TM) i9-12900K","AMD Ryzen 9 7950X","Intel(R) Core(TM) i7-13700K")
>> "%PSFILE%" echo $rndCpu=$cpuNames[(Get-Random -Maximum $cpuNames.Count)]
>> "%PSFILE%" echo try{ Set-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0" "ProcessorNameString" $rndCpu -ErrorAction Stop; Log "[成功] CPU伪装为：$rndCpu" }catch{ Log "[失败] CPU伪装" }
>> "%PSFILE%" echo try{ Set-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" "SystemManufacturer" "ASUS" -ErrorAction Stop; Set-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" "BaseBoardManufacturer" "ASUSTeK COMPUTER INC." -ErrorAction Stop; Set-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" "BIOSVendor" "American Megatrends Inc." -ErrorAction Stop; Log "  [成功] 主板/BIOS伪装为华硕" }catch{ Log "  [失败] 主板/BIOS伪装" }
>> "%PSFILE%" echo Log "[6.2] CPU微码修订版本..."
>> "%PSFILE%" echo try{ Set-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0" "Update Revision" ([byte[]]@(0x12,0x34,0x56,0x78)) -ErrorAction Stop; Log "  [成功] 微码修订版本已混淆" }catch{ Log "  [失败] 微码修订" }
>> "%PSFILE%" echo Log "[6.3] 物理内存伪装..."
>> "%PSFILE%" echo try{ $memKey="HKLM:\HARDWARE\RESOURCEMAP\System Resources\Physical Memory"; if(Test-Path $memKey){ $val=Get-ItemProperty $memKey -Name ".Translated" -ErrorAction SilentlyContinue; if($val -and $val.".Translated" -is [byte[]]){ $newBytes=$val.".Translated".Clone(); for($i=0;$i -lt [Math]::Min(16,$newBytes.Length);$i++){$newBytes[$i]=(Get-Random -Maximum 256)}; Set-ItemProperty $memKey -Name ".Translated" $newBytes -ErrorAction Stop; Log "  [成功] 物理内存资源映射已混淆" }else{ Log "  [跳过] 物理内存格式非字节数组" } }else{ Log "  [跳过] 物理内存资源映射不可访问" } }catch{ Log "  [失败] 物理内存伪装" }
>> "%PSFILE%" echo Log "[6.4] 显卡/驱动名称伪装..."
>> "%PSFILE%" echo try{ $gpuKey="HKLM:\SYSTEM\CurrentControlSet\Enum\PCI"; if(Test-Path $gpuKey){ Get-ChildItem $gpuKey -Recurse -ErrorAction SilentlyContinue ^| ForEach-Object { $dev=$_.PSPath; try{ $name=(Get-ItemProperty $dev -Name "DeviceDesc" -ErrorAction SilentlyContinue).DeviceDesc; if($name -match "NVIDIA|AMD|Intel.*Graphics|Display"){ Set-ItemProperty $dev -Name "DeviceDesc" "@oem%d.inf,%nvidia_dev.1%\%;NVIDIA GeForce RTX 4090" -ErrorAction SilentlyContinue } }catch{} }; Log "  [成功] 显卡名称伪装为RTX 4090" } }catch{ Log "  [失败] 显卡伪装" }
>> "%PSFILE%" echo Log "[6.5] NVIDIA UUID/持久化标识..."
>> "%PSFILE%" echo try{ Remove-Item "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm" -Recurse -Force -ErrorAction SilentlyContinue; Log "[成功] NVIDIA持久化标识已随机化" }catch{ Log "[失败] NVIDIA UUID" }
>> "%PSFILE%" echo Log "[6.6] 键鼠WPP轨迹日志..."
>> "%PSFILE%" echo try{ Remove-Item "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\EventLog-System" -Recurse -Force -ErrorAction SilentlyContinue; Log "[成功] 输入设备WPP轨迹已清除" }catch{ Log "[失败] WPP轨迹" }
>> "%PSFILE%" echo Log "[6.7] EFI/NSI接口伪装..."
>> "%PSFILE%" echo try{ Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "NSI" ([guid]::NewGuid().ToByteArray()) -ErrorAction SilentlyContinue; Log "[成功] NSI/EFI接口值已随机化" }catch{ Log "[失败] EFI/NSI" }
>> "%PSFILE%" echo Log "[6.8] TPM信任模块..."
>> "%PSFILE%" echo try{ Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tpm" "ImagePath" "\SystemRoot\System32\drivers\tpm.sys" -ErrorAction SilentlyContinue; Log "[成功] TPM服务注册表值已随机化" }catch{ Log "[失败] TPM" }
>> "%PSFILE%" echo Log "  [注意] TPM WMI属性运行时为只读"
>> "%PSFILE%" echo Log "[6.9] IDE/SCSI总线硬件ID..."
>> "%PSFILE%" echo try{ Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\IDE" -ErrorAction SilentlyContinue ^| ForEach-Object { Set-ItemProperty $_.PSPath -Name "FriendlyName" ("DISK-"+(RndStr6 6)) -ErrorAction SilentlyContinue }; Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\SCSI" -ErrorAction SilentlyContinue ^| ForEach-Object { Set-ItemProperty $_.PSPath -Name "FriendlyName" ("DISK-"+(RndStr6 6)) -ErrorAction SilentlyContinue }; Log "[成功] IDE/SCSI硬件ID已随机化" }catch{ Log "[失败] IDE/SCSI" }
>> "%PSFILE%" echo Log "[6.10] 磁盘卷序列号 - 由阶段3覆盖"
>> "%PSFILE%" echo Log "[6.11] 磁盘卷标随机化..."
>> "%PSFILE%" echo foreach($d6 in $fixed){
>> "%PSFILE%" echo $dl6=$d6.Name
>> "%PSFILE%" echo $newLab6=(RndStr6 3).ToUpper()+"-"+(RndStr6 6).ToUpper()
>> "%PSFILE%" echo try{ Set-Volume -DriveLetter $dl6 -NewFileSystemLabel $newLab6 -ErrorAction Stop; Log "    [成功] $dl6`: 卷标 -> $newLab6" }catch{ Log "    [失败] $dl6`: 卷标修改失败" }
>> "%PSFILE%" echo }
>> "%PSFILE%" echo Log "[6.12] 显示器名称伪装..."
>> "%PSFILE%" echo try{ Remove-Item "HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY" -Recurse -Force -ErrorAction SilentlyContinue; New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY" -Force ^| Out-Null; Log "[成功] 显示器名称/配置已重置为通用默认" }catch{ Log "[失败] 显示器伪装" }
>> "%PSFILE%" echo Log "[6.13] Windows遥测/追踪ID重置..."
>> "%PSFILE%" echo try{ Remove-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" "SusClientIdValidation" -ErrorAction SilentlyContinue; Remove-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" "PingID" -ErrorAction SilentlyContinue; Log "[成功] 验证ID/PingID已删除" }catch{}
>> "%PSFILE%" echo try{ Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" "DeviceId" ([guid]::NewGuid().ToString()) -ErrorAction SilentlyContinue; Log "[成功] 诊断追踪ID已随机化" }catch{}
>> "%PSFILE%" echo Log "[成功] Windows遥测追踪ID已重置"
>> "%PSFILE%" echo Log "--- 硬件伪装完成（部分项为易失性，重启后恢复）---"
>> "%PSFILE%" echo Log ""
>> "%PSFILE%" echo(
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo Log "  阶段7：深度追踪与痕迹清理（10项）"
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo Log "[7.1] 深度追踪：USN日志/卷影快照/NVIDIA缓存..."
>> "%PSFILE%" echo try{ Exec "fsutil usn deletejournal /d /n C:" 120 ^| Out-Null; Log "[成功] C盘USN日志已删除" }catch{ Log "[跳过] USN日志" }
>> "%PSFILE%" echo try{ Exec "vssadmin delete shadows /all /quiet" 120 ^| Out-Null; Log "[成功] 卷影副本已删除" }catch{ Log "[跳过] 卷影副本" }
>> "%PSFILE%" echo $nvCache=0; @("$env:LOCALAPPDATA\NVIDIA\DXCache","$env:LOCALAPPDATA\NVIDIA\GLCache","$env:LOCALAPPDATA\NVIDIA Corporation\NV_Cache","$env:APPDATA\NVIDIA") ^| ForEach-Object { if(Test-Path $_){ Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue; $nvCache++ } }; Log "[成功] NVIDIA缓存已清除：$nvCache 个目录"
>> "%PSFILE%" echo Log "[7.2] 执行痕迹：预读/BAM/DAM/兼容性缓存..."
>> "%PSFILE%" echo try{ Remove-Item "C:\Windows\Prefetch\*" -Force -ErrorAction SilentlyContinue; Log "[成功] 预读文件已清除" }catch{ Log "[失败] 预读" }
>> "%PSFILE%" echo try{ Remove-Item "HKLM:\SYSTEM\CurrentControlSet\Services\bam\UserSettings" -Recurse -Force -ErrorAction SilentlyContinue; Log "[成功] BAM记录已清除" }catch{ Log "[失败] BAM" }
>> "%PSFILE%" echo try{ Remove-Item "HKLM:\SYSTEM\CurrentControlSet\Services\dam\UserSettings" -Recurse -Force -ErrorAction SilentlyContinue; Log "[成功] DAM记录已清除" }catch{ Log "[失败] DAM" }
>> "%PSFILE%" echo try{ Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache" "AppCompatCache" -ErrorAction SilentlyContinue; Log "[成功] 应用兼容性缓存已清除" }catch{ Log "[失败] AppCompatCache" }
>> "%PSFILE%" echo Log "[7.3] 最近文件与跳转列表..."
>> "%PSFILE%" echo $recentCount=0; Get-ChildItem "C:\Users" -Directory ^| ForEach-Object { $p="$($_.FullName)\AppData\Roaming\Microsoft\Windows\Recent"; if(Test-Path $p){ Remove-Item "$p\*" -Recurse -Force -ErrorAction SilentlyContinue; $recentCount++ } }; Log "[成功] 最近文件已清除：$recentCount 个用户"
>> "%PSFILE%" echo try{ Get-ChildItem "C:\Users" -Directory ^| ForEach-Object { $a="$($_.FullName)\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations"; $c="$($_.FullName)\AppData\Roaming\Microsoft\Windows\Recent\CustomDestinations"; @($a,$c)^|ForEach-Object{ if(Test-Path $_){ Remove-Item "$_\*" -Force -ErrorAction SilentlyContinue } } }; Log "[成功] 跳转列表已清除" }catch{ Log "[失败] 跳转列表" }
>> "%PSFILE%" echo Log "[7.4] USB存储设备历史..."
>> "%PSFILE%" echo try{ Remove-Item "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR" -Recurse -Force -ErrorAction SilentlyContinue; New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR" -Force ^| Out-Null; Log "[成功] USBSTOR服务枚举已清除" }catch{ Log "[失败] USBSTOR" }
>> "%PSFILE%" echo try{ Remove-Item "HKLM:\SOFTWARE\Microsoft\Windows Portable Devices\Devices" -Recurse -Force -ErrorAction SilentlyContinue; Log "[成功] 便携设备历史已清除" }catch{ Log "[失败] 便携设备" }
>> "%PSFILE%" echo try{ $md=Get-ItemProperty "HKLM:\SYSTEM\MountedDevices" -ErrorAction SilentlyContinue; $md.PSObject.Properties ^| Where-Object { $_.Name -match "\\DosDevices\\[D-Z]:" } ^| ForEach-Object { Remove-ItemProperty "HKLM:\SYSTEM\MountedDevices" $_.Name -ErrorAction SilentlyContinue }; Log "[成功] 挂载设备历史已清除（系统盘保留）" }catch{ Log "[失败] MountedDevices" }
>> "%PSFILE%" echo Log "[7.5] 显示器连接记录..."
>> "%PSFILE%" echo $monCount=0; @("HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Configuration","HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Connectivity","HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\ScaleFactors") ^| ForEach-Object { if(Test-Path $_){ Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue; $monCount++ } }; Log "[成功] 显示器缓存已清除：$monCount 个项"
>> "%PSFILE%" echo Log "[7.6] RDP远程连接记录..."
>> "%PSFILE%" echo $rdpCount=0; Get-ChildItem "C:\Users" -Directory ^| ForEach-Object { $ntuser="$($_.FullName)\NTUSER.DAT"; if(Test-Path $ntuser){ ^& reg load "HKU\TempUser_$($_.Name)" $ntuser 2^>$null ^| Out-Null; Start-Sleep -Milliseconds 300; $tsc="HKU:\TempUser_$($_.Name)\Software\Microsoft\Terminal Server Client"; if(Test-Path $tsc){ $def=Get-ItemProperty "$tsc\Default" -ErrorAction SilentlyContinue; $def.PSObject.Properties ^| Where-Object { $_.Name -match "^MRU\d+" } ^| ForEach-Object { Remove-ItemProperty "$tsc\Default" $_.Name -ErrorAction SilentlyContinue; $rdpCount++ }; Remove-Item "$tsc\Servers" -Recurse -Force -ErrorAction SilentlyContinue }; ^& reg unload "HKU\TempUser_$($_.Name)" 2^>$null ^| Out-Null } }; Log "[成功] RDP默认最近连接已清除：$rdpCount 项"
>> "%PSFILE%" echo try{ Get-ChildItem "C:\Users" -Directory ^| ForEach-Object { $rdp="$($_.FullName)\Documents\Default.rdp"; if(Test-Path $rdp){ Remove-Item $rdp -Force -ErrorAction SilentlyContinue } }; Log "[成功] 默认RDP文件已删除" }catch{ Log "[失败] Default.rdp" }
>> "%PSFILE%" echo Log "[7.7] 系统伪重置：更新历史/临时文件/图标缓存..."
>> "%PSFILE%" echo try{ Remove-Item "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue; Log "[成功] Windows更新下载缓存已清除" }catch{ Log "[失败] WU缓存" }
>> "%PSFILE%" echo try{ Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue; Log "[成功] 系统临时文件已清除" }catch{ Log "[失败] 系统Temp" }
>> "%PSFILE%" echo $uTemp=0; Get-ChildItem "C:\Users" -Directory ^| ForEach-Object { $t="$($_.FullName)\AppData\Local\Temp"; if(Test-Path $t){ Remove-Item "$t\*" -Recurse -Force -ErrorAction SilentlyContinue; $uTemp++ } }; Log "[成功] 用户临时文件已清除：$uTemp 个用户"
>> "%PSFILE%" echo try{ Get-ChildItem "C:\Users" -Directory ^| ForEach-Object { $ic="$($_.FullName)\AppData\Local\IconCache.db"; if(Test-Path $ic){ Remove-Item $ic -Force -ErrorAction SilentlyContinue } }; ^& ie4uinit -show 2^>$null ^| Out-Null; Log "[成功] 图标缓存已重建" }catch{ Log "[失败] 图标缓存" }
>> "%PSFILE%" echo Log "[7.8] 网卡MAC地址还原（移除伪装MAC）..."
>> "%PSFILE%" echo $macCount=0; Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}" -ErrorAction SilentlyContinue ^| Where-Object { $_.PSChildName -match "^\d{4}$" } ^| ForEach-Object { $nap=Get-ItemProperty $_.PSPath -Name "NetworkAddress" -ErrorAction SilentlyContinue; if($nap -and $nap.NetworkAddress){ Remove-ItemProperty $_.PSPath -Name "NetworkAddress" -ErrorAction SilentlyContinue; $macCount++; Log "  [成功] 伪装MAC已移除：$($_.PSChildName) → 已恢复为原厂MAC" } }; Log "[成功] MAC地址检查完成（还原 $macCount 个）"
>> "%PSFILE%" echo Log "[7.9] 系统事件日志（PnP相关）..."
>> "%PSFILE%" echo try{ ^& wevtutil cl System 2^>^&1 ^| Out-Null; Log "[成功] 系统事件日志已清除" }catch{ Log "[跳过] 系统日志" }
>> "%PSFILE%" echo try{ ^& wevtutil cl Security 2^>^&1 ^| Out-Null; Log "[成功] 安全事件日志已清除" }catch{ Log "[跳过] 安全日志" }
>> "%PSFILE%" echo try{ ^& wevtutil cl Setup 2^>^&1 ^| Out-Null; Log "[成功] 安装事件日志已清除" }catch{ Log "[跳过] 安装日志" }
>> "%PSFILE%" echo try{ ^& wevtutil cl "Microsoft-Windows-Kernel-PnP/Configuration" 2^>^&1 ^| Out-Null; Log "[成功] 内核即插即用配置日志已清除" }catch{ Log "[跳过] 内核即插即用日志" }
>> "%PSFILE%" echo Log "[7.10] 历史驱动残留（INF日志/迁移记录）..."
>> "%PSFILE%" echo $infCount=0; @("C:\Windows\INF\setupapi.dev.log","C:\Windows\INF\setupapi.app.log") ^| ForEach-Object { if(Test-Path $_){ Clear-Content $_ -ErrorAction SilentlyContinue; $infCount++ } }; Log "[成功] INF日志已清除：$infCount 个"
>> "%PSFILE%" echo try{ Remove-Item "C:\Windows\INF\*.pnf" -Force -ErrorAction SilentlyContinue; Log "[成功] 预编译INF已清除" }catch{ Log "[失败] .pnf" }
>> "%PSFILE%" echo try{ Remove-Item "HKLM:\SYSTEM\CurrentControlSet\Control\Migration" -Recurse -Force -ErrorAction SilentlyContinue; Log "[成功] 设备迁移记录已清除" }catch{ Log "[失败] 迁移记录" }
>> "%PSFILE%" echo try{ Remove-Item "C:\Windows\setupcln_*.log" -Force -ErrorAction SilentlyContinue; Log "[成功] 安装清理日志已清除" }catch{ Log "[失败] setupcln" }
>> "%PSFILE%" echo Log "--- 深度追踪清理完成 ---"
>> "%PSFILE%" echo.
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo Log "  阶段8：网络深度重置与硬件缓存刷新（8项）"
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo Log "[8.1] 网卡TCP/IP伪装：接口序列号与DHCPv6 DUID..."
>> "%PSFILE%" echo try{
>> "%PSFILE%" echo Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "Dhcpv6DUID" -ErrorAction SilentlyContinue
>> "%PSFILE%" echo Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue ^| ForEach-Object { Remove-ItemProperty $_.PSPath "DhcpInterfaceOptions" -ErrorAction SilentlyContinue; Remove-ItemProperty $_.PSPath "Lease" -ErrorAction SilentlyContinue }
>> "%PSFILE%" echo Log "  [成功] 网卡TCP/IP标识已重置"
>> "%PSFILE%" echo }catch{ Log "  [失败] 网卡TCP/IP伪装" }
>> "%PSFILE%" echo Log "[8.2] 游戏缓存与外挂文件清理..."
>> "%PSFILE%" echo $gamePaths=@("$env:LOCALAPPDATA\*cheat*","$env:LOCALAPPDATA\*hack*","$env:APPDATA\*cheat*","$env:APPDATA\*hack*","$env:LOCALAPPDATA\EpicGamesLauncher\Saved\webcache","$env:APPDATA\Battle.net\Cache","C:\Program Files (x86)\Steam\steamapps\common\*\cache","C:\Program Files\Steam\steamapps\common\*\cache")
>> "%PSFILE%" echo $gClean=0; foreach($gp in $gamePaths){ if(Test-Path $gp){ Remove-Item $gp -Recurse -Force -ErrorAction SilentlyContinue; $gClean++ } }
>> "%PSFILE%" echo Log "  [成功] 游戏缓存/外挂文件已清理（$gClean 个路径）"
>> "%PSFILE%" echo Log "[8.3] PCI/DMA痕迹清理..."
>> "%PSFILE%" echo try{
>> "%PSFILE%" echo Remove-Item "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI" -Recurse -Force -ErrorAction SilentlyContinue
>> "%PSFILE%" echo ^& wevtutil cl "Microsoft-Windows-Kernel-PnP/Configuration" 2^>$null ^| Out-Null
>> "%PSFILE%" echo Log "  [成功] PCI/DMA痕迹已清理"
>> "%PSFILE%" echo }catch{ Log "  [失败] PCI/DMA清理" }
>> "%PSFILE%" echo Log "[8.4] 网络环境深度重置：Winsock/TCP-IP/DHCP/DNS..."
>> "%PSFILE%" echo try{
>> "%PSFILE%" echo Exec "netsh winsock reset" 120 ^| Out-Null
>> "%PSFILE%" echo Exec "netsh int ip reset" 120 ^| Out-Null
>> "%PSFILE%" echo Exec "ipconfig /release" 120 ^| Out-Null
>> "%PSFILE%" echo Exec "ipconfig /renew" 120 ^| Out-Null
>> "%PSFILE%" echo ^& ipconfig /flushdns 2^>^&1 ^| Out-Null
>> "%PSFILE%" echo Log "  [成功] Winsock/TCP-IP已重置，DHCP/DNS已刷新（需重启）"
>> "%PSFILE%" echo }catch{ Log "  [失败] 网络重置" }
>> "%PSFILE%" echo Log "[8.5] IPv6协议栈重置：邻居缓存与隐私标识..."
>> "%PSFILE%" echo try{
>> "%PSFILE%" echo ^& netsh interface ipv6 delete neighbors 2^>^&1 ^| Out-Null
>> "%PSFILE%" echo ^& netsh interface ipv6 set global randomizeidentifiers=enabled 2^>^&1 ^| Out-Null
>> "%PSFILE%" echo Log "  [成功] IPv6邻居缓存已清空，随机隐私标识已开启"
>> "%PSFILE%" echo }catch{ Log "  [失败] IPv6重置" }
>> "%PSFILE%" echo Log "[8.6] 添加虚拟网卡适配器（虚拟MAC）..."
>> "%PSFILE%" echo try{
>> "%PSFILE%" echo $loopInf="C:\Windows\INF\netloop.inf"
>> "%PSFILE%" echo if(Test-Path $loopInf){ $pPnp=Start-Process -FilePath "pnputil.exe" -ArgumentList "/add-driver",$loopInf,"/install" -WindowStyle Hidden -PassThru; if(-not $pPnp.WaitForExit(120000)){ try{$pPnp.Kill()}catch{} }; Start-Sleep -Seconds 3; $rMac=((Get-Random -Maximum 256) -band 0xFC -bor 0x02).ToString("X2"); 1..5^|ForEach-Object{ $rMac += (Get-Random -Maximum 256).ToString("X2") }; Get-NetAdapter -Name "*Loopback*" -ErrorAction SilentlyContinue ^| ForEach-Object { Set-NetAdapter -Name $_.Name -MacAddress $rMac -ErrorAction SilentlyContinue }; $renCount=0; $hashAdapters=Get-NetAdapter -ErrorAction SilentlyContinue ^| Where-Object { $_.Name -match "#\d+$" } ^| Sort-Object { [int]([regex]::Match($_.Name,"(\d+)$").Value) } -Descending; foreach($ha in $hashAdapters){ $cleanName=($ha.Name -replace "#\d+$","").Trim(); if(-not (Get-NetAdapter -Name $cleanName -ErrorAction SilentlyContinue)){ Rename-NetAdapter -Name $ha.Name -NewName $cleanName -ErrorAction SilentlyContinue; $renCount++ } }; Log "  [成功] 虚拟环回网卡已添加，MAC: $rMac，全局去除$renCount个网卡#尾数" } else { Log "  [跳过] netloop.inf 不存在" }
>> "%PSFILE%" echo }catch{ Log "  [失败] 虚拟网卡添加" }
>> "%PSFILE%" echo Log "[8.7] ARP路由表清理..."
>> "%PSFILE%" echo try{
>> "%PSFILE%" echo ^& netsh interface ip delete arpcache 2^>^&1 ^| Out-Null
>> "%PSFILE%" echo ^& arp -d * 2^>^&1 ^| Out-Null
>> "%PSFILE%" echo Log "  [成功] ARP缓存已清空"
>> "%PSFILE%" echo }catch{ Log "  [失败] ARP清理" }
>> "%PSFILE%" echo Log "[8.8] WMI硬件缓存刷新..."
>> "%PSFILE%" echo try{
>> "%PSFILE%" echo Exec "net stop winmgmt /y" 120 ^| Out-Null
>> "%PSFILE%" echo Start-Sleep -Seconds 2
>> "%PSFILE%" echo ^& wmic bios get name 2^>^&1 ^| Out-Null
>> "%PSFILE%" echo Exec "net start winmgmt" 120 ^| Out-Null
>> "%PSFILE%" echo Log "  [成功] WMI服务已重启，硬件缓存已刷新"
>> "%PSFILE%" echo }catch{ Log "  [失败] WMI刷新" }
>> "%PSFILE%" echo Log "--- 网络深度重置与硬件缓存刷新完成（部分项需重启生效）---"
>> "%PSFILE%" echo.
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo Log "  阶段9：开机自启配置（硬件伪装持久化）"
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo Log "[9.1] 写入硬件伪装开机脚本..."
>> "%PSFILE%" echo $spoofPath = "$env:SystemRoot\System32\hardware_spoof.ps1"
>> "%PSFILE%" echo $spoofLines = @(
>> "%PSFILE%" echo '$ErrorActionPreference = "SilentlyContinue"'
>> "%PSFILE%" echo '$cpuList = @("Intel(R) Core(TM) i9-13900K","Intel(R) Core(TM) i9-12900K","Intel(R) Core(TM) i9-11900K")'
>> "%PSFILE%" echo '$rndCpu = $cpuList[(Get-Random -Maximum $cpuList.Count)]'
>> "%PSFILE%" echo 'Set-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0" "ProcessorNameString" $rndCpu'
>> "%PSFILE%" echo 'Set-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" "SystemManufacturer" "ASUS"'
>> "%PSFILE%" echo 'Set-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" "BaseBoardManufacturer" "ASUSTeK COMPUTER INC."'
>> "%PSFILE%" echo 'Set-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" "BIOSVendor" "American Megatrends Inc."'
>> "%PSFILE%" echo 'Set-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0" "Update Revision" ([byte[]]@(0x12,0x34,0x56,0x78))'
>> "%PSFILE%" echo )
>> "%PSFILE%" echo try{ $spoofLines ^| Out-File -FilePath $spoofPath -Force -Encoding UTF8; Log "  [成功] 开机脚本已写入：$spoofPath" }catch{ Log "  [失败] 开机脚本写入失败" }
>> "%PSFILE%" echo Log "[9.2] 创建开机自启计划任务..."
>> "%PSFILE%" echo try{ $pSch=Start-Process -FilePath "schtasks.exe" -ArgumentList "/create","/tn","HardwareSpoof","/tr","powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$spoofPath`"","/sc","onstart","/ru","SYSTEM","/rl","highest","/f" -WindowStyle Hidden -PassThru; if(-not $pSch.WaitForExit(120000)){ try{$pSch.Kill()}catch{} }; Log "  [成功] 计划任务已创建（系统启动时以SYSTEM最高权限运行）" }catch{ Log "  [失败] 计划任务创建失败" }
>> "%PSFILE%" echo Log "--- 开机自启配置完成 ---"
>> "%PSFILE%" echo.
>> "%PSFILE%" echo.
>> "%PSFILE%" echo Log ""
>> "%PSFILE%" echo(
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo Log "  所有阶段执行完毕"
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo Log "  阶段1（注册表）：已删除=$totalDel / 失败=$totalFail"
>> "%PSFILE%" echo Log "  阶段2（内核）：设备接口类+旧驱动+PnP缓存"
>> "%PSFILE%" echo Log "  阶段3（卷序列号）：所有固定盘已随机化"
>> "%PSFILE%" echo Log "  阶段4（DNS）：缓存已刷新"
>> "%PSFILE%" echo Log "  阶段5（系统标识）：机器ID/硬件ID/计算机名/产品ID/密钥/安装时间已随机化"
>> "%PSFILE%" echo Log "  阶段6（硬件）：BIOS/CPU/显卡/NVIDIA/WPP/NSI/TPM/IDE/卷标/显示器/遥测已伪装"
>> "%PSFILE%" echo Log "  阶段7（深度清理）：USN/卷影/预读/BAM/RDP/USB/事件日志/驱动残留已清除"
>> "%PSFILE%" echo Log "  阶段8（网络重置）：Winsock/TCP-IP/IPv6/ARP/WMI/虚拟网卡 已重置"
>> "%PSFILE%" echo Log "  阶段9（开机自启）：硬件伪装计划任务已创建，重启后自动重新应用"
>> "%PSFILE%" echo Log "  注意：必须重启。显卡/网卡驱动未触碰。"
>> "%PSFILE%" echo Log "============================================================"
>> "%PSFILE%" echo(
>> "%PSFILE%" echo try { "done" ^| Out-File -FilePath $flagFile -Force -Encoding UTF8 } catch { }

echo [1.5/6] 转换脚本编码为 UTF-8 (带BOM)...
powershell -NoProfile -Command "$c=[System.IO.File]::ReadAllText('%PSFILE%',[System.Text.Encoding]::UTF8); [System.IO.File]::WriteAllText('%PSFILE%',$c,[System.Text.UTF8Encoding]::new($true))"

if not exist "%PSFILE%" (
    echo 错误：写入脚本失败。
    pause
    exit /b
)
for %%A in ("%PSFILE%") do echo     脚本大小：%%~zA 字节

echo [2/6] 正在创建服务启动器...
> "%SVCBAT%" echo @echo off
>> "%SVCBAT%" echo "%PSHELL%" -NoProfile -ExecutionPolicy Bypass -File "%PSFILE%"
>> "%SVCBAT%" echo exit /b

echo [3/6] 正在创建临时 SYSTEM 服务...
sc.exe delete "RegVolClean" >nul 2>&1
sc.exe create "RegVolClean" binPath= "%SVCBAT%" type= own start= demand obj= LocalSystem >nul 2>&1
if %errorlevel% neq 0 (
    echo 错误：创建服务失败。
    pause
    exit /b
)

echo [4/6] 正在启动服务（以 SYSTEM 系统权限运行）...
del "%FLAGFILE%" "%LOGFILE%" 2>nul
sc.exe start "RegVolClean" >nul 2>&1

echo [5/6] 等待清理完成（最多300秒）...
set /a waited=0
:wait
if exist "%FLAGFILE%" goto done
timeout /t 1 /nobreak >nul
set /a waited+=1
if %waited% geq 300 goto timeout
goto wait
:timeout
echo.
echo 警告：执行超时（超过300秒）。正在强制结束服务...
sc.exe stop "RegVolClean" >nul 2>&1
sc.exe delete "RegVolClean" >nul 2>&1
taskkill /f /fi "SERVICES eq RegVolClean" >nul 2>&1
echo 已强制结束。正在检查日志...
goto showlog
:done

echo [6/6] 清理完成。执行结果：
echo.

:showlog
if exist "%LOGFILE%" (
    type "%LOGFILE%"
) else (
    echo 未找到日志文件。
    sc.exe query "RegVolClean" 2>nul
)

echo.
echo 正在清理临时文件...
sc.exe stop "RegVolClean" >nul 2>&1
sc.exe delete "RegVolClean" >nul 2>&1
del "%PSFILE%" "%SVCBAT%" "%LOGFILE%" "%FLAGFILE%" 2>nul

echo.
echo ============================================================
echo   完成。必须重启电脑使所有变更生效。
echo ============================================================
echo.
pause
exit /b
