# Concertx — Evaluación 2

Concertx es una app para sincronizar efectos de luces y vibración entre los
asistentes de un concierto: un usuario diseña los efectos por canción,
genera un código de 6 caracteres y lo comparte; el resto de asistentes se
une con ese código y su teléfono (y su smartwatch, vía BLE) se sincroniza
con el show.

## Estructura del proyecto

```
Evaluacion/  (este directorio, C:\evaluacion)
├── concertx_movil/       App Android (Flutter) — teléfono
├── concertx_wearable/    App Wear OS (Flutter) — reloj
├── concertx_tv/          PWA para Smart TV — pantalla del recinto
└── backend/              API REST + WebSocket (Express.js + PostgreSQL/Supabase)
    └── db_concertx.sql   Esquema de base de datos
```

## Requisitos

- Flutter SDK 3.x (probado con 3.44, Dart 3.12)
- Android Studio con al menos un emulador Android y un emulador Wear OS
- Node.js 18+
- Una base de datos PostgreSQL (recomendado: proyecto de Supabase)
- Chrome (o cualquier navegador con soporte de Service Workers) para
  `concertx_tv`, y algún servidor estático (`npx serve`, `python -m
  http.server`, etc.)

## Inicio rápido (`iniciar_todo.bat`)

Si ya cumples los requisitos de abajo (backend con `.env` configurado y
`npm install` hecho, `flutter pub get` corrido en `concertx_movil` y
`concertx_wearable`, y **los dos emuladores ya abiertos**), puedes levantar
todo el ecosistema con un solo doble clic:

```
iniciar_todo.bat
```

Qué hace (ver el propio archivo, `C:\evaluacion\iniciar_todo.bat`, para el
detalle línea por línea):

1. Abre una ventana de consola y corre `npm run dev` en `backend/`
   → API + WebSocket en `http://localhost:3000`.
2. Espera 3 segundos y abre otra ventana con `npx serve . -l 8080` en
   `concertx_tv/` → PWA de la TV en `http://localhost:8080`.
3. Abre una tercera ventana con `flutter run -d emulator-5554` en
   `concertx_movil/` (app del teléfono).
4. Abre una cuarta ventana con `flutter run -d emulator-5556` en
   `concertx_wearable/` (app del reloj).

Se abren **4 ventanas independientes**; cada una se detiene con `Ctrl+C` sin
afectar a las demás. La ventana original del `.bat` ya no hace falta y se
puede cerrar.

**Importante — IDs de emulador:** `emulator-5554` y `emulator-5556` son los
IDs que tenían los emuladores (teléfono y Wear OS) abiertos cuando se
generó el script. Si abres los emuladores en otro orden o usas otros AVDs,
esos IDs cambian. Antes de correr el `.bat`:

1. Abre **ambos** emuladores (teléfono y Wear OS) desde Android Studio y
   espera a que terminen de cargar.
2. En cualquier terminal corre:
   ```
   flutter devices
   ```
3. Si los IDs que aparecen no son `emulator-5554` / `emulator-5556`, edita
   `iniciar_todo.bat` y reemplaza esos valores en las dos líneas
   `flutter run -d ...` por los IDs reales.

Si el backend o la TV ya están corriendo (por ejemplo, los dejaste
abiertos de una sesión anterior), simplemente cierra la ventana anterior o
ignora el error de "puerto en uso" en la ventana nueva — no rompe nada.

### Requisitos previos al `.bat` (solo la primera vez)

```
cd backend
cp .env.example .env
# Edita .env con tus credenciales reales — nunca lo subas a git
npm install

cd ../concertx_movil
flutter pub get

cd ../concertx_wearable
flutter pub get
```

## Cómo ejecutar cada parte manualmente

Si prefieres no usar el `.bat` (por ejemplo para ver los logs de cada
proceso por separado, o correr solo una parte), esta es la forma manual,
componente por componente:

### 1. Backend

```
cd backend
cp .env.example .env
# Edita .env con tus credenciales (DATABASE_URL, JWT_SECRET, ...)
npm install
# Carga el esquema en tu base de datos, por ejemplo con psql:
#   psql "$DATABASE_URL" -f db_concertx.sql
npm run dev
```

El servidor queda escuchando en `http://localhost:3000`.

### 2. App móvil (concertx_movil)

```
cd concertx_movil
flutter pub get
flutter run
```

La app apunta por defecto a `http://10.0.2.2:3000/api` (así es como el
emulador estándar de Android ve el `localhost` de tu máquina). Si pruebas
en un dispositivo físico, cambia `baseUrl` en
`lib/core/constants/api_constants.dart` por la IP de tu máquina en la red
local.

### 3. App wearable (concertx_wearable)

```
cd concertx_wearable
flutter pub get
# (Opcional) regenerar el ícono personalizado si cambiaste assets/icon/app_icon.png:
#   dart run flutter_launcher_icons
# Inicia un emulador Wear OS (redondo, API 30+) desde Android Studio
flutter run
```

### 4. App Smart TV — Concertx TV (PWA)

```
cd concertx_tv
# Sirve los archivos estáticos con cualquier servidor, por ejemplo:
npx serve . -p 8080
# o con Python:
python -m http.server 8080
```

Abrir en Chrome:
1. Ir a `http://localhost:8080`
2. DevTools (F12) → Device toolbar → Custom: **1920x1080**
3. User agent: *Chromecast with Google TV* (opcional, para simular TV)

Para instalar como PWA:
- Chrome muestra el ícono de instalación en la barra de direcciones, o
- Menú `⋮` → **Instalar Concertx TV**

Verificar la PWA en DevTools → **Application** → Manifest / Service Workers.

**Navegación D-pad:** usa las flechas del teclado para moverte entre las
3 tarjetas del dashboard; `Enter` o `Espacio` activa la tarjeta enfocada
(usuarios refresca, canción avanza, efecto cicla color). El anillo dorado
indica el elemento con foco.

## Sincronización BLE (teléfono ↔ reloj)

- El reloj (`concertx_wearable`) abre un servidor GATT (modo periférico)
  usando `BluetoothGattServer` nativo en Android (ver
  `MainActivity.kt`) porque `flutter_blue_plus` solo soporta el rol
  central. Expone 3 características **NOTIFY**: ritmo (BPM), color de
  efecto (`#RRGGBB`) y estado de vibración.
- El teléfono (`concertx_movil`) actúa como central: escanea, se conecta
  y se suscribe a esas 3 características vía `flutter_blue_plus`
  (`lib/core/services/ble_service.dart`).
- Los UUIDs están definidos en `lib/core/constants/ble_constants.dart` en
  **ambos** proyectos y deben coincidir exactamente.
- El botón "Iniciar/Detener" en la pantalla del reloj controla la
  generación de datos simulados (BPM, color, vibración).
- El teléfono no debe crashear si el reloj se desconecta; el estado BLE
  se refleja como escaneando/conectado/error/desconectado y se reintenta
  la reconexión automáticamente.

## Sincronización en vivo teléfono → TV (WebSocket)

El backend expone un servidor WebSocket (`ws://localhost:3000`, ver
`backend/src/ws/index.js`) al que se conectan tanto el teléfono como la
TV:

- El teléfono se identifica con `{type:'phone_connect'}` y manda
  `effect_update` cada vez que el color del efecto activo cambia
  (dato que viene del reloj por BLE/HTTP — ver
  `lib/core/providers/wearable_provider.dart` y
  `lib/core/services/sync_service.dart`).
- La TV se identifica con `{type:'tv_connect'}` y recibe esos mensajes
  automáticamente (`concertx_tv/js/app.js`), actualizando el círculo de
  "Efecto activo" sin que nadie toque la Smart TV.
- Si la TV no tiene red hacia el backend, sigue funcionando con los
  últimos datos guardados en `localStorage`/cache del Service Worker
  (modo offline) y el WebSocket se reconecta solo cada 3 segundos.
- `concertx_tv` también escucha un `BroadcastChannel('concertx_sync')`
  como respaldo para pruebas donde el teléfono (emulado en Chrome) y la
  TV comparten el mismo navegador/dispositivo.

El endpoint `GET /api/eventos/conectados` (público) alimenta el contador
"Usuarios conectados" de la TV a partir de la tabla `asistentes_evento`
real en Supabase.

## Emuladores usados

- Teléfono: emulador Android estándar, ~2 GB RAM, Android 13.
- Wearable: Wear OS Round, API 30, ~1 GB RAM.

## Ícono / logo de la app

El ícono del launcher de `concertx_movil` (el que aparece en el menú de
apps del teléfono) sale de `concertx_movil/assets/icon/app_icon.png`
(recortado de `logo.png`, en la raíz del proyecto) y se genera con
[`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons),
igual que en `concertx_wearable`. Si cambias el logo, regenera los íconos:

```
cd concertx_movil
# reemplaza assets/icon/app_icon.png por el nuevo logo (cuadrado, ideal 1024x1024)
dart run flutter_launcher_icons
```

## Variables de entorno

Ver `backend/.env.example`. **Nunca** commitear el archivo `.env` real ni
llaves de firma (`.jks`, `.keystore`) — están excluidos tanto en
`backend/.gitignore` como en el `.gitignore` raíz del proyecto
(`C:\evaluacion\.gitignore`), que también excluye `.claude/` y cualquier
otro archivo de credenciales antes de subir el repo a GitHub.
