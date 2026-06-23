@echo off
REM Sobe o Oraculo (Ollama + modelo, via Docker) e lanca o jogo (Godot nativo).
REM Uso: run.bat
setlocal enabledelayedexpansion
cd /d "%~dp0"

set CONTAINER=oraculo-ollama

REM --- 1. Verifica dependencias -----------------------------------------------
where docker >nul 2>nul
if errorlevel 1 (
  echo ERRO: Docker nao encontrado no PATH. Instale o Docker e tente de novo.
  exit /b 1
)

REM Resolve o binario do Godot: 1) GODOT_BIN  2) 'godot' no PATH  3) locais comuns
set GODOT=
if defined GODOT_BIN (
  if exist "%GODOT_BIN%" (set "GODOT=%GODOT_BIN%") else (echo AVISO: GODOT_BIN='%GODOT_BIN%' nao existe; tentando outras opcoes...)
)
if not defined GODOT (
  for /f "delims=" %%g in ('where godot 2^>nul') do if not defined GODOT set "GODOT=%%g"
)
if not defined GODOT (
  for %%g in (
    "%USERPROFILE%\Godot\Godot_v4.6-stable_win64.exe"
    "%USERPROFILE%\Downloads\Godot_v4.6-stable_win64.exe"
    "%ProgramFiles%\Godot\Godot.exe"
  ) do if not defined GODOT if exist "%%~g" set "GODOT=%%~g"
)
if not defined GODOT (
  echo ERRO: nao encontrei o Godot.
  echo   - aponte o binario:  set GODOT_BIN=C:\caminho\para\godot.exe ^&^& run.bat
  echo   - ou coloque 'godot' no PATH ^(Godot 4.6^).
  exit /b 1
)
echo ^>^> Usando Godot: %GODOT%

REM --- 2. Sobe o modelo -------------------------------------------------------
echo ^>^> Subindo o Oraculo (Ollama + modelo)...
docker compose up -d

REM --- 3. Espera o modelo ficar pronto ----------------------------------------
echo ^>^> Aguardando o modelo ficar pronto (na primeira vez baixa ~2 GB, pode demorar)...
:waitloop
set STATUS=
for /f %%i in ('docker inspect -f "{{.State.Health.Status}}" %CONTAINER% 2^>nul') do set STATUS=%%i
if not "!STATUS!"=="healthy" (
  timeout /t 2 /nobreak >nul
  goto waitloop
)
echo ^>^> Modelo pronto.

REM --- 4. Lanca o jogo --------------------------------------------------------
echo ^>^> Iniciando o jogo...
"%GODOT%" --path .

REM --- 5. Encerra o modelo ao fechar o jogo -----------------------------------
echo ^>^> Encerrando o Oraculo...
docker compose down
endlocal
