@echo off
setlocal
where Godot_v4.7.1-stable_win64.exe >nul 2>nul
if errorlevel 1 (
  echo Godot 4.7.1 was not found on PATH.
  echo Open project.godot in Godot and press F5.
  pause
  exit /b 1
)
start "" Godot_v4.7.1-stable_win64.exe --path "%~dp0." --log-file "%~dp0qa-output\play.log"
