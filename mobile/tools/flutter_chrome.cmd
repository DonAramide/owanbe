@echo off
REM Flutter CHROME_EXECUTABLE stub (official Flutter mechanism).
REM Chrome 111+ requires --remote-allow-origins=* for DWDS debugging.
REM Flutter invokes this with its own flags (--user-data-dir, --remote-debugging-port, url, etc.).
setlocal
set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" (
  echo flutter_chrome.cmd: Google Chrome not found. Install Chrome or set CHROME_EXECUTABLE. >&2
  exit /b 1
)
"%CHROME%" --remote-allow-origins=* %*
