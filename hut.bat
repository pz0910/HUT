@echo off
setlocal enabledelayedexpansion

REM HUT - HTML 托管展示平台 CLI 工具 (Windows)
REM 用法: hut.bat <command> [options]

set "SCRIPT_DIR=%~dp0"
set "MANIFEST=%SCRIPT_DIR%manifest.json"
set "APPS_DIR=%SCRIPT_DIR%apps"

REM 确保 apps 目录存在
if not exist "%APPS_DIR%" mkdir "%APPS_DIR%"
if not exist "%MANIFEST%" echo {"items":[]} > "%MANIFEST%"

if "%~1"=="" goto :help
if "%~1"=="help" goto :help_cmd
if "%~1"=="upload" goto :upload
if "%~1"=="list" goto :list
if "%~1"=="delete" goto :delete
if "%~1"=="update" goto :update
if "%~1"=="replace" goto :replace
if "%~1"=="push" goto :push
echo ❌ 未知命令: %~1
goto :help

REM === upload ===
:upload
shift
set "FILE="
set "NAME="
set "DESC="
set "CAT="
set "TAGS="

:parse_upload
if "%~1"=="" goto :check_upload
if "%~1"=="--name" (set "NAME=%~2" & shift & shift & goto :parse_upload)
if "%~1"=="--desc" (set "DESC=%~2" & shift & shift & goto :parse_upload)
if "%~1"=="--cat" (set "CAT=%~2" & shift & shift & goto :parse_upload)
if "%~1"=="--tags" (set "TAGS=%~2" & shift & shift & goto :parse_upload)
set "FILE=%~1"
shift
goto :parse_upload

:check_upload
if "%FILE%"=="" (
    echo ❌ 用法: hut upload ^<file.html^> --name "名称" --desc "描述" --cat "分类" [--tags "t1,t2"]
    exit /b 1
)
if "%NAME%"=="" (
    echo ❌ 缺少必填参数: --name, --desc, --cat 均为必填
    exit /b 1
)
if "%DESC%"=="" (
    echo ❌ 缺少必填参数: --name, --desc, --cat 均为必填
    exit /b 1
)
if "%CAT%"=="" (
    echo ❌ 缺少必填参数: --name, --desc, --cat 均为必填
    exit /b 1
)
if not exist "%FILE%" (
    echo ❌ 文件不存在: %FILE%
    exit /b 1
)

REM 检查 .html 后缀
set "EXT=%FILE:~-5%"
if /i not "%EXT%"==".html" (
    echo ❌ 仅支持 .html 文件
    exit /b 1
)

REM 生成 ID 并复制文件
powershell -NoProfile -Command ^
  "$id = -join ((97..122) + (48..57) | Get-Random -Count 6 | ForEach-Object {[char]$_}); " ^
  "$manifest = Get-Content '%MANIFEST%' -Raw | ConvertFrom-Json; " ^
  "$tagsArr = @(); if ('%TAGS%' -ne '') { $tagsArr = '%TAGS%' -split ',' | ForEach-Object { $_.Trim() } }; " ^
  "$item = [PSCustomObject]@{id=$id;name='%NAME%';description='%DESC%';category='%CAT%';filename=\"$id.html\";uploaded_at=(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ');tags=$tagsArr}; " ^
  "$manifest.items += $item; " ^
  "$manifest | ConvertTo-Json -Depth 5 | Set-Content '%MANIFEST%' -Encoding UTF8; " ^
  "Copy-Item '%FILE%' \"%APPS_DIR%\$id.html\"; " ^
  "Write-Host \"✅ 已上传: %NAME% (id: $id)\"; " ^
  "Write-Host \"   运行 'hut push' 推送到 GitHub Pages\""

cd /d "%SCRIPT_DIR%"
git add manifest.json apps/ 2>nul
git commit -m "feat: 添加 %NAME%" --quiet 2>nul
goto :eof

REM === list ===
:list
shift
set "CAT_FILTER="
set "SEARCH="

:parse_list
if "%~1"=="" goto :do_list
if "%~1"=="--cat" (set "CAT_FILTER=%~2" & shift & shift & goto :parse_list)
if "%~1"=="--search" (set "SEARCH=%~2" & shift & shift & goto :parse_list)
shift
goto :parse_list

:do_list
powershell -NoProfile -Command ^
  "$m = Get-Content '%MANIFEST%' -Raw | ConvertFrom-Json; " ^
  "if ($m.items.Count -eq 0) { Write-Host '暂无已上传的 HTML 页面'; exit }; " ^
  "$items = $m.items; " ^
  "if ('%CAT_FILTER%' -ne '') { $items = $items | Where-Object { $_.category -eq '%CAT_FILTER%' } }; " ^
  "if ('%SEARCH%' -ne '') { $items = $items | Where-Object { $_.name -like '*%SEARCH%*' -or $_.description -like '*%SEARCH%*' } }; " ^
  "$items = $items | Sort-Object uploaded_at -Descending; " ^
  "Write-Host ('{0,-10} {1,-20} {2,-10} {3}' -f 'ID','名称','分类','上传时间'); " ^
  "Write-Host ('{0,-10} {1,-20} {2,-10} {3}' -f '──','────','────','────────'); " ^
  "foreach ($i in $items) { Write-Host ('{0,-10} {1,-20} {2,-10} {3}' -f $i.id,$i.name,$i.category,$i.uploaded_at) }"
goto :eof

REM === delete ===
:delete
shift
if "%~1"=="" (
    echo ❌ 用法: hut delete ^<id^>
    exit /b 1
)
set "DEL_ID=%~1"

powershell -NoProfile -Command ^
  "$m = Get-Content '%MANIFEST%' -Raw | ConvertFrom-Json; " ^
  "$found = $m.items | Where-Object { $_.id -eq '%DEL_ID%' }; " ^
  "if (-not $found) { Write-Host '❌ 未找到 ID: %DEL_ID%'; exit 1 }; " ^
  "$name = $found.name; " ^
  "Remove-Item '%APPS_DIR%\%DEL_ID%.html' -ErrorAction SilentlyContinue; " ^
  "$m.items = @($m.items | Where-Object { $_.id -ne '%DEL_ID%' }); " ^
  "$m | ConvertTo-Json -Depth 5 | Set-Content '%MANIFEST%' -Encoding UTF8; " ^
  "Write-Host \"✅ 已删除: $name\""

cd /d "%SCRIPT_DIR%"
git add manifest.json apps/ 2>nul
git commit -m "feat: 删除 %DEL_ID%" --quiet 2>nul
goto :eof

REM === update ===
:update
shift
if "%~1"=="" (
    echo ❌ 用法: hut update ^<id^> [--name "名称"] [--desc "描述"] [--cat "分类"] [--tags "t1,t2"]
    exit /b 1
)
set "UPD_ID=%~1"
shift

set "UPD_NAME="
set "UPD_DESC="
set "UPD_CAT="
set "UPD_TAGS="

:parse_update
if "%~1"=="" goto :do_update
if "%~1"=="--name" (set "UPD_NAME=%~2" & shift & shift & goto :parse_update)
if "%~1"=="--desc" (set "UPD_DESC=%~2" & shift & shift & goto :parse_update)
if "%~1"=="--cat" (set "UPD_CAT=%~2" & shift & shift & goto :parse_update)
if "%~1"=="--tags" (set "UPD_TAGS=%~2" & shift & shift & goto :parse_update)
shift
goto :parse_update

:do_update
powershell -NoProfile -Command ^
  "$m = Get-Content '%MANIFEST%' -Raw | ConvertFrom-Json; " ^
  "$item = $m.items | Where-Object { $_.id -eq '%UPD_ID%' }; " ^
  "if (-not $item) { Write-Host '❌ 未找到 ID: %UPD_ID%'; exit 1 }; " ^
  "if ('%UPD_NAME%' -ne '') { $item.name = '%UPD_NAME%' }; " ^
  "if ('%UPD_DESC%' -ne '') { $item.description = '%UPD_DESC%' }; " ^
  "if ('%UPD_CAT%' -ne '') { $item.category = '%UPD_CAT%' }; " ^
  "if ('%UPD_TAGS%' -ne '') { $item.tags = '%UPD_TAGS%' -split ',' | ForEach-Object { $_.Trim() } }; " ^
  "$m | ConvertTo-Json -Depth 5 | Set-Content '%MANIFEST%' -Encoding UTF8; " ^
  "Write-Host '✅ 已更新: %UPD_ID%'"

cd /d "%SCRIPT_DIR%"
git add manifest.json 2>nul
git commit -m "feat: 更新 %UPD_ID% 元数据" --quiet 2>nul
goto :eof

REM === replace ===
:replace
shift
if "%~1"=="" (
    echo ❌ 用法: hut replace ^<id^> ^<file.html^>
    exit /b 1
)
if "%~2"=="" (
    echo ❌ 用法: hut replace ^<id^> ^<file.html^>
    exit /b 1
)
set "REP_ID=%~1"
set "REP_FILE=%~2"

if not exist "%REP_FILE%" (
    echo ❌ 文件不存在: %REP_FILE%
    exit /b 1
)

powershell -NoProfile -Command ^
  "$m = Get-Content '%MANIFEST%' -Raw | ConvertFrom-Json; " ^
  "$found = $m.items | Where-Object { $_.id -eq '%REP_ID%' }; " ^
  "if (-not $found) { Write-Host '❌ 未找到 ID: %REP_ID%'; exit 1 }; " ^
  "Copy-Item '%REP_FILE%' '%APPS_DIR%\%REP_ID%.html' -Force; " ^
  "Write-Host '✅ 已替换: %REP_ID%'"

cd /d "%SCRIPT_DIR%"
git add apps/ 2>nul
git commit -m "feat: 替换 %REP_ID% 文件" --quiet 2>nul
goto :eof

REM === push ===
:push
cd /d "%SCRIPT_DIR%"
git push origin gh-pages
echo ✅ 已推送到 GitHub Pages
goto :eof

REM === help ===
:help
if "%~1"=="" goto :help_all
:help_cmd
if "%~2"=="upload" (
    echo 用法: hut upload ^<file.html^> --name "名称" --desc "描述" --cat "分类" [--tags "t1,t2"]
    goto :eof
)
if "%~2"=="list" (
    echo 用法: hut list [--cat 分类] [--search 关键词]
    goto :eof
)
if "%~2"=="delete" (
    echo 用法: hut delete ^<id^>
    goto :eof
)
if "%~2"=="update" (
    echo 用法: hut update ^<id^> [--name "名称"] [--desc "描述"] [--cat "分类"] [--tags "t1,t2"]
    goto :eof
)
if "%~2"=="replace" (
    echo 用法: hut replace ^<id^> ^<file.html^>
    goto :eof
)
if "%~2"=="push" (
    echo 用法: hut push
    echo 执行 git push 到远程仓库，触发 GitHub Pages 更新
    goto :eof
)

:help_all
echo HUT - HTML 托管展示平台 CLI 工具
echo.
echo 用法: hut ^<命令^> [选项]
echo.
echo 命令:
echo   upload ^<file^>   上传新 HTML 页面
echo   list            列出已上传的 HTML
echo   delete ^<id^>     删除指定 HTML
echo   update ^<id^>     更新元数据
echo   replace ^<id^>    替换 HTML 文件
echo   push            推送到 GitHub Pages
echo   help [cmd]      显示帮助信息
echo.
echo 运行 'hut help ^<command^>' 查看命令详情
goto :eof