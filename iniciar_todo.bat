@echo off
REM ============================================================
REM  Concertx - Lanzador de todo el ecosistema con un solo doble clic
REM ============================================================
REM Abre 4 ventanas nuevas, cada una con su propio proceso:
REM   1) Backend (Express)        -> puerto 3000
REM   2) Concertx TV (estatico)   -> puerto 8080
REM   3) App movil (Flutter)      -> emulador de telefono
REM   4) App wearable (Flutter)   -> emulador Wear OS
REM
REM Los IDs de emulador (emulator-5554 / emulator-5556) son los que
REM tenian tus dos AVDs abiertos al generar este script. Si algun dia
REM cambian (por ejemplo si abres los emuladores en otro orden), corre
REM "flutter devices" en cualquier terminal para ver los IDs actuales
REM y actualiza las dos lineas de "flutter run -d ..." de abajo.
REM ============================================================

echo Iniciando Concertx: backend, TV, movil y wearable...
echo.

start "Concertx Backend (3000)" cmd /k "cd /d C:\evaluacion\backend && npm run dev"

timeout /t 3 /nobreak >nul

start "Concertx TV (8080)" cmd /k "cd /d C:\evaluacion\concertx_tv && npx --yes serve . -l 8080"

start "Concertx Movil (emulator-5554)" cmd /k "cd /d C:\evaluacion\concertx_movil && flutter run -d emulator-5554"

start "Concertx Wearable (emulator-5556)" cmd /k "cd /d C:\evaluacion\concertx_wearable && flutter run -d emulator-5556"

echo.
echo Se abrieron 4 ventanas nuevas: Backend, TV, Movil y Wearable.
echo Cada una se puede cerrar/detener por separado con Ctrl+C.
echo Esta ventana ya no hace falta, puedes cerrarla.
echo.
pause
