@echo off
REM Abre o jogo numa janela de 1080x1920 de verdade, mesmo sendo maior que o
REM monitor. A captura de janela pega a janela inteira, inclusive a parte que
REM nao cabe na tela, entao a imagem chega no tamanho certo e nao precisa de
REM zoom, que era o que borrava.
REM
REM O conector precisa estar rodando antes, porque e ele que serve o jogo.

set URL=http://localhost:8080
set TAM=--window-size=1080,1920 --window-position=0,0

if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" (
  start "" "%ProgramFiles%\Google\Chrome\Application\chrome.exe" --new-window %TAM% --app=%URL%
  goto fim
)
if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" (
  start "" "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" --new-window %TAM% --app=%URL%
  goto fim
)
if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" (
  start "" "%LocalAppData%\Google\Chrome\Application\chrome.exe" --new-window %TAM% --app=%URL%
  goto fim
)

echo Nao achei o Chrome. Abra ele na mao em %URL%
pause
:fim
