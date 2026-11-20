@echo off
rem ============================================================
rem  PotPlayer AI Translate - local model warmup helper
rem
rem  Why: PotPlayer aborts any script HTTP request after ~8.5s.
rem  A cold local model needs 10-30s to load, and Ollama cancels
rem  the load when the client disconnects - so the first subtitle
rem  request can never load it. This script loads the model from
rem  OUTSIDE PotPlayer and keeps it resident (keep_alive=24h).
rem
rem  Usage:
rem     warmup-ollama.bat
rem     warmup-ollama.bat <model> [chat-completions-url]
rem
rem  Defaults match a local Ollama at 127.0.0.1:11434.
rem ============================================================
setlocal

set MODEL=%~1
if "%MODEL%"=="" set MODEL=translategemma:12b

set URL=%~2
if "%URL%"=="" set URL=http://127.0.0.1:11434/v1/chat/completions

set BODY=%TEMP%\aitrans_warm_body.json
set CURL=%SystemRoot%\System32\curl.exe

if not exist "%CURL%" (
    echo [ERROR] curl.exe not found at %CURL%
    pause
    exit /b 1
)

> "%BODY%" echo {"model":"%MODEL%","messages":[{"role":"user","content":"hi"}],"stream":false,"max_tokens":1,"keep_alive":"24h"}

echo.
echo [AI Translate] loading "%MODEL%" from:
echo     %URL%
echo     first load usually takes 10-30s, please wait...
echo.

"%CURL%" -s -m 300 -X POST "%URL%" -H "Content-Type: application/json" --data-binary "@%BODY%" -o NUL
if errorlevel 1 echo [WARN] request failed - is Ollama running? (try: ollama serve)

echo.
echo [AI Translate] resident models now:
echo.
ollama ps
echo.
echo If "%MODEL%" is listed above with "UNTIL  24 hours from now",
echo the warmup worked - go back to PotPlayer and translate.
echo Otherwise check the model name and that Ollama is running.
echo.
pause
endlocal
