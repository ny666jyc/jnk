@echo off
chcp 65001 >nul
title C盘安全清理工具 v1.0
color 0A

:: ==============================================
::  C盘安全清理工具
::  仅清理：系统缓存、临时文件、垃圾残留
::  保留：系统核心文件、所有个人资料
:: ==============================================

echo.
echo ==============================================
echo          C盘安全清理工具 v1.0
echo ==============================================
echo.
echo 【安全说明】
echo   - 仅清理临时文件、系统缓存、垃圾残留
echo   - 不会删除任何系统核心文件
echo   - 不会删除您的文档、图片、下载等个人资料
echo   - 建议关闭正在运行的软件后再执行清理
echo.

:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [提示] 检测到未以管理员身份运行，部分系统缓存可能无法清理。
    echo        如需完整清理，请右键选择"以管理员身份运行"。
    echo.
)

echo 按任意键开始扫描可清理空间...
pause >nul
echo.

:: ==============================================
::  计算清理前C盘可用空间
:: ==============================================
echo 正在获取C盘空间信息...
for /f "tokens=3" %%a in ('dir c:\ /-c ^| find "可用字节"') do set free_before=%%a
echo.

:: ==============================================
::  开始清理
:: ==============================================
set total_cleaned=0
set /a count=0

echo ==============================================
echo  正在清理：用户临时文件  (%%temp%%)
echo ==============================================
set "target=%temp%"
call :CleanFolder "%target%"

echo.
echo ==============================================
echo  正在清理：系统临时文件  (C:\Windows\Temp)
echo ==============================================
set "target=C:\Windows\Temp"
call :CleanFolder "%target%"

echo.
echo ==============================================
echo  正在清理：Windows预读取缓存  (Prefetch)
echo ==============================================
set "target=C:\Windows\Prefetch"
call :CleanFolder "%target%"

echo.
echo ==============================================
echo  正在清理：Windows更新下载缓存
echo ==============================================
set "target=C:\Windows\SoftwareDistribution\Download"
call :CleanFolder "%target%"

echo.
echo ==============================================
echo  正在清理：系统缩略图缓存
echo ==============================================
:: 清理当前用户缩略图缓存
set "target=%localappdata%\Microsoft\Windows\Explorer"
if exist "%target%" (
    del /f /s /q "%target%\iconcache_*.db" 2>nul
    del /f /s /q "%target%\thumbcache_*.db" 2>nul
    echo   缩略图缓存已清理
)

echo.
echo ==============================================
echo  正在清理：浏览器缓存
echo ==============================================
:: Chrome缓存
set "target=%localappdata%\Google\Chrome\User Data\Default\Cache"
if exist "%target%" (
    echo   - Google Chrome 缓存
    del /f /s /q "%target%\*.*" 2>nul
    for /d %%d in ("%target%\*") do rd /s /q "%%d" 2>nul
)

:: Edge缓存
set "target=%localappdata%\Microsoft\Edge\User Data\Default\Cache"
if exist "%target%" (
    echo   - Microsoft Edge 缓存
    del /f /s /q "%target%\*.*" 2>nul
    for /d %%d in ("%target%\*") do rd /s /q "%%d" 2>nul
)

:: Firefox缓存
set "target=%localappdata%\Mozilla\Firefox\Profiles"
if exist "%target%" (
    echo   - Mozilla Firefox 缓存
    for /d %%d in ("%target%\*") do (
        if exist "%%d\cache2" (
            del /f /s /q "%%d\cache2\*.*" 2>nul
            for /d %%x in ("%%d\cache2\*") do rd /s /q "%%x" 2>nul
        )
    )
)

echo.
echo ==============================================
echo  正在清理：系统日志文件
echo ==============================================
:: Windows日志
set "target=C:\Windows\Logs"
if exist "%target%" (
    del /f /s /q "%target%\*.log" 2>nul
    del /f /s /q "%target%\*.etl" 2>nul
    echo   Windows日志已清理
)

:: ==============================================
::  询问是否清空回收站
:: ==============================================
echo.
echo ==============================================
set /p recycle=  是否清空回收站？(Y/N): 
if /i "%recycle%"=="Y" (
    echo  正在清空回收站...
    rd /s /q C:\$Recycle.Bin 2>nul
    echo   回收站已清空
) else (
    echo   跳过回收站清理
)

:: ==============================================
::  清理完成统计
:: ==============================================
echo.
echo ==============================================
echo  清理完成！
echo ==============================================
echo.

:: 计算清理后可用空间
for /f "tokens=3" %%a in ('dir c:\ /-c ^| find "可用字节"') do set free_after=%%a

echo 清理前可用空间: %free_before% 字节
echo 清理后可用空间: %free_after% 字节
echo.

:: 尝试计算释放空间（简单估算）
echo 【提示】已完成以下项目清理：
echo   1. 用户临时文件
echo   2. 系统临时文件
echo   3. Windows预读取缓存
echo   4. Windows更新下载缓存
echo   5. 系统缩略图缓存
echo   6. 主流浏览器缓存（Chrome/Edge/Firefox）
echo   7. 系统日志文件
echo.
echo 所有系统核心文件和您的个人资料均已完整保留。
echo.
echo 按任意键退出...
pause >nul
exit /b

:: ==============================================
::  清理文件夹子程序
:: ==============================================
:CleanFolder
set "folder=%~1"
if not exist "%folder%" (
    echo   目录不存在，跳过
    goto :eof
)

:: 删除文件
del /f /s /q "%folder%\*.*" 2>nul

:: 删除子文件夹
for /d %%d in ("%folder%\*") do (
    rd /s /q "%%d" 2>nul
)

echo   清理完成
goto :eof
