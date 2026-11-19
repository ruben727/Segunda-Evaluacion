# Matriz de pruebas de seguridad y base de datos — Concertx (Prácticas 9 y 10)

## Decisión de arquitectura

La práctica propone Firebase/Firestore. Concertx ya tiene una **base de datos compartida**: PostgreSQL
(Supabase) detrás de la API **Express** desplegada en Vercel, a la que se conectan la app móvil, la TV y el
wearable. Se usa esa misma base en lugar de agregar Firestore. Las reglas de acceso que en Firestore
irían en `firestore.rules` aquí están en el **backend**:

| Regla | Dónde se aplica |
|-------|-----------------|
| Hay que tener sesión para todo lo de incidencias | `verificarToken` en `routes/incidencias.routes.js` |
| El rol se lee de la BD en cada petición (no del JWT) | `middleware/roles.js → cargarRol` |
| Un usuario solo ve y edita **sus** incidencias | `controllers/incidencias.controller.js → cargarIncidencia` (403 si no es suya) |
| `creado_por` y `estado` inicial los fija el servidor | `crear()` ignora esos campos del body |
| Solo agente/admin listan todas, cambian estado y asignan | `requiereRol('agente','admin')` y validación en `actualizar()` |
| Solo admin limpia el historial | `requiereRol('admin')` en `DELETE /incidencias` |
| Solo valores de las listas (sin texto libre) | Validación en el controlador **y** `CHECK` en la tabla |

En la app, ocultar el panel de gestión a los usuarios es solo de interfaz; aunque alguien llame a la API
directamente, el servidor responde 403.

## Cómo ejecutar

```bash
cd backend
BASE_URL=https://backend-three-xi-95.vercel.app/api \
ADMIN_CORREO=admin@concertx.app ADMIN_PASSWORD='<contraseña>' \
node pruebas/incidencias_seguridad.js
```

El script crea dos clientes de prueba (`cliente.a.*@test.com`, `cliente.b.*@test.com`). No ejecuta
"limpiar historial" con el admin, para no borrar tickets reales.

**Ejecución registrada:** 2026-11-05, contra la API en local (`node server.js`) conectada a la BD de
Supabase de producción → **19/19 pasan**. Después del despliegue se repitió contra `https://backend-three-xi-95.vercel.app/api` → **19/19 pasan** (columna "Vercel").

## Seguridad (SEG)

| ID | Caso | Entrada | Resultado esperado | Resultado obtenido (local) | Vercel | Evidencia |
|----|------|---------|--------------------|----------------------------|--------|-----------|
| SEG-01 | Sin token no se accede a incidencias | `GET /incidencias/mias` sin `Authorization` | 401 | 401 "Token no proporcionado" — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
| SEG-02 | Un token alterado se rechaza | `Bearer <token>x` | 401 | 401 "Token inválido o expirado" — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
| SEG-03 | Contraseña de más de 64 caracteres en login → mensaje genérico | password de 65 caracteres | 401 "Correo o contraseña incorrectos" | 401 mensaje genérico — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
| SEG-04 | Login con campos de solo espacios | correo `"   "`, password `"        "` | 400 | 400 — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
| SEG-05 | El cliente B no ve las incidencias de A en "Mis incidencias" | `GET /incidencias/mias` con token de B | 200, sin incidencias de A | 200, ninguna de A — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
| SEG-06 | El cliente B no puede leer la incidencia de A por id | `GET /incidencias/{idA}` con token de B | 403 | 403 — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
| SEG-07 | El cliente B no puede editar la incidencia de A | `PATCH /incidencias/{idA}` `{prioridad:"Baja"}` con token de B | 403 | 403 — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
| SEG-08 | Un cliente no puede listar todas las incidencias | `GET /incidencias` con token de cliente | 403 | 403 — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
| SEG-09 | Un cliente no puede cambiar el estado ni de su propia incidencia | `PATCH /incidencias/{idA}` `{estado:"Resuelto"}` con token de A | 403 | 403 — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
| SEG-10 | Un cliente no puede limpiar el historial | `DELETE /incidencias` con token de cliente | 403 | 403 — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |

## Base de datos compartida (DB)

| ID | Caso | Entrada | Resultado esperado | Resultado obtenido (local) | Vercel | Evidencia |
|----|------|---------|--------------------|----------------------------|--------|-----------|
| DB-01 | Crear una incidencia válida | `{tipo:"Falla de equipo", equipo:"Smartwatch", prioridad:"Alta"}` | 201, estado "Pendiente" | 201 Pendiente — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
| DB-02 | `creado_por` y `estado` los fija el servidor | body con `creado_por` de B y `estado:"Resuelto"` | 201, `creado_por`=A, estado Pendiente | Ignorados — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
| DB-03 | Falta una opción obligatoria | sin `prioridad` | 400 | 400 "Selecciona prioridad" — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
| DB-04 | Valor fuera de la lista (texto libre) | `tipo:"Mi texto libre"` | 400 | 400 "Opción de tipo no válida" — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
| DB-05 | Persistencia: lo creado se puede volver a leer | `GET /incidencias/mias` de A | Contiene la incidencia creada | Presente — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
| DB-06 | El dueño puede editar su incidencia pendiente | `PATCH {prioridad:"Media"}` con token de A | 200, prioridad Media | 200 Media — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
| DB-07 | El admin ve las incidencias de todos los clientes | `GET /incidencias` con token de admin | 200, incluye la de A | Incluida — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
| DB-08 | El cambio del admin se ve desde el cliente (BD compartida) | admin `PATCH {estado:"En proceso"}` → A consulta `/mias` | A ve "En proceso" | "En proceso" — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
| DB-09 | Estado fuera de la lista se rechaza | admin `PATCH {estado:"Cerrado"}` | 400 | 400 — Pasa | Pasa | 19/19 en Vercel, 2026-11-05 |
