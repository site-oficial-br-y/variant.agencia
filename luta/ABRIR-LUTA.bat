@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Jogo da Luta

REM Dois cliques e pronto: acha o conector e o jogo (mesmo com nomes
REM baguncados tipo "conector (7).js"), copia pra nomes limpos, liga o
REM conector e abre o jogo no navegador. Tem que estar DENTRO da pasta
REM torcida, do lado do conector e do node_modules.

REM ---------- usuario ----------
if not exist usuario-luta.txt (
  echo.
  set /p DIGITADO=Digite seu @ do TikTok, sem o arroba, e aperte Enter:
  >usuario-luta.txt echo %DIGITADO%
)
set /p USUARIO=<usuario-luta.txt

REM ---------- acha o conector mais novo ----------
set CONECTOR=
for /f "delims=" %%F in ('dir /b /a-d /o-d "conector*.js" 2^>nul') do if not defined CONECTOR set CONECTOR=%%F
if not defined CONECTOR (
  echo Nao achei nenhum conector .js nesta pasta.
  echo Coloque este arquivo na mesma pasta do conector.
  pause
  exit /b
)
copy /y "%CONECTOR%" rodar-luta.js >nul

REM ---------- acha o jogo da luta mais novo ----------
set JOGO=
for /f "delims=" %%F in ('dir /b /a-d /o-d "quem-ganha-a-luta*.html" 2^>nul') do if not defined JOGO set JOGO=%%F
if not defined JOGO (
  echo Nao achei o arquivo do jogo "quem-ganha-a-luta.html".
  echo Coloque ele nesta pasta.
  pause
  exit /b
)
copy /y "%JOGO%" jogo-luta.html >nul

REM ---------- liga o conector numa janela propria ----------
start "conector" cmd /k node rodar-luta.js %USUARIO%

REM da um tempo pro servidor subir antes de abrir o navegador
timeout /t 4 /nobreak >nul

REM ---------- abre o jogo no navegador ----------
start "" "http://localhost:8080/jogo-luta.html"

echo.
echo Pronto. O jogo abriu no navegador e o conector esta na outra janela preta.
echo Nao feche a janela preta. No TikTok LIVE Studio, capture a janela do navegador.
echo.
timeout /t 8 /nobreak >nul
