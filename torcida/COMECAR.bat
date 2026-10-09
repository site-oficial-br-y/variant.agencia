@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Qual torcida e maior

REM Um clique so: atualiza os arquivos, liga o conector e abre a janela do
REM jogo ja no tamanho certo e com a musica liberada. Antes isso era quatro
REM passos na mao e sempre faltava um.

set REPO=https://raw.githubusercontent.com/site-oficial-br-y/variant.agencia/main/torcida

REM ---------- usuario ----------
REM Fica guardado em usuario.txt, entao so pergunta na primeira vez.
if not exist usuario.txt (
  echo.
  set /p USUARIO=Seu @ do TikTok (sem o arroba):
  >usuario.txt echo %USUARIO%
)
set /p USUARIO=<usuario.txt
if "%USUARIO%"=="" (
  echo Nao achei o usuario. Apague o usuario.txt e rode de novo.
  pause
  exit /b
)

REM ---------- atualiza ----------
echo Atualizando o jogo...
curl -s -L -o index.html.novo "%REPO%/index.html" && move /y index.html.novo index.html >nul
curl -s -L -o conector.js.novo "%REPO%/conector.js" && move /y conector.js.novo conector.js >nul
if not exist musicas mkdir musicas
curl -s -L -o musicas\lista.json "%REPO%/musicas/lista.json"

REM Baixa so a musica que ainda nao esta aqui: as que ja tem nao vem de novo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "try { $l = Get-Content 'musicas/lista.json' -Raw | ConvertFrom-Json } catch { $l = @() };" ^
  "foreach ($m in $l) { if (-not (Test-Path \"musicas/$m\")) {" ^
  "  Write-Host \"  baixando $m\";" ^
  "  try { Invoke-WebRequest (\"%REPO%/musicas/\" + [uri]::EscapeDataString($m)) -OutFile \"musicas/$m\" } catch {}" ^
  "} }"

REM ---------- conector ----------
echo Ligando o conector...
start "conector" cmd /k node conector.js %USUARIO%

REM Ele precisa de um tempo pra subir o servidor antes do Chrome pedir a pagina.
timeout /t 4 /nobreak >nul

REM ---------- janela do jogo ----------
REM A janela e maior que o monitor de proposito: a captura pega a janela
REM inteira, entao a imagem chega em 1080x1920 sem zoom, que era o que borrava.
REM O autoplay liberado faz a musica comecar sozinha, sem precisar clicar no simbolo.
set URL=http://localhost:8080
set FLAGS=--new-window --window-size=1080,1920 --window-position=0,0 --autoplay-policy=no-user-gesture-required --app=%URL%

if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" (
  start "" "%ProgramFiles%\Google\Chrome\Application\chrome.exe" %FLAGS%
  goto pronto
)
if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" (
  start "" "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" %FLAGS%
  goto pronto
)
if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" (
  start "" "%LocalAppData%\Google\Chrome\Application\chrome.exe" %FLAGS%
  goto pronto
)
echo Nao achei o Chrome. Abra ele na mao em %URL%

:pronto
echo.
echo Pronto. No LIVE Studio, capture a janela do Chrome.
echo Se aparecer a faixa vermelha, o conector caiu: olhe a outra janela preta.
echo.
timeout /t 6 /nobreak >nul
