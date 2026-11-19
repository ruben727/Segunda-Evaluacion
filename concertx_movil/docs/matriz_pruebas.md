# Matriz de pruebas de caja negra — Concertx (Práctica 8)

- **Archivo de pruebas:** `test/caja_negra_test.dart`
- **Cómo ejecutar:** `flutter test test/caja_negra_test.dart -r expanded`
- **Fecha de ejecución:** 2026-11-05 · **Resultado:** 12/12 pasan

Las pruebas usan solo entradas y salidas públicas (validadores, `IncidenciaProvider` y la pantalla
"Reportar incidencia"). El backend se sustituye por `ApiFalsa`, que responde con los mismos códigos
HTTP que la API real (201, 400, 403, 500). Las reglas del **servidor** se prueban contra la API real con
`backend/pruebas/incidencias_seguridad.js` (ver `docs/matriz_pruebas_seguridad.md`).

| ID | Categoría | Criterio de aceptación | Entrada | Resultado esperado | Resultado obtenido | Estado |
|----|-----------|------------------------|---------|--------------------|--------------------|--------|
| REQ-01 | Operación principal | Reportar con las tres opciones guarda la incidencia en estado Pendiente | tipo=Falla de equipo, equipo=Smartwatch, prioridad=Alta | 1 incidencia, estado "Pendiente", creadoPor = usuario actual | 1 incidencia Pendiente con creadoPor=1 y las opciones elegidas | Pasa |
| REQ-02 | Operación principal | "Mis incidencias" muestra solo las del usuario autenticado | Usuario 1 y usuario 2 reportan una cada uno; se recarga como usuario 2 | Solo 1 incidencia, de creadoPor=2 | 1 incidencia, todas de creadoPor=2 | Pasa |
| REQ-03 | Operación principal | El administrador cambia el estado a "En proceso" y luego a "Resuelto" | Rol admin; cambiarEstado(En proceso) → cambiarEstado(Resuelto) | Sin error; el estado se refleja en cada paso | "En proceso" y luego "Resuelto" | Pasa |
| REQ-04 | Operación principal | El agente asigna un agente a la incidencia y puede quitarlo | Rol agente; asignarAgente(9) → asignarAgente(null) | agenteAsignado=9 y luego null | 9 → null | Pasa |
| REQ-05 | Validación | Sin elegir todas las opciones no se guarda y se avisa; no hay campo de texto libre | Pantalla: solo "Acceso perdido" → Enviar; luego se completan equipo y prioridad → Enviar | 0 TextField; SnackBar "Selecciona: equipo, prioridad"; 0 llamadas a la API; después 1 llamada y SnackBar de confirmación | Sin TextField; aviso mostrado; 0 llamadas → 1 llamada y "Incidencia registrada…" | Pasa |
| REQ-06 | Validación | La contraseña con menos de 8 o más de 64 caracteres se rechaza | "Abc1234" (7), 65 caracteres, "Abc12345" (8), 64 caracteres, "abcdefgh", "Segura123" | Error en 7 y 65; válido en 8 y 64; registro exige mayúscula y número | "Mínimo 8…", "Máximo 64…", null, null, "Debe incluir…", null | Pasa |
| REQ-07 | Validación | Los campos con solo espacios se tratan como vacíos | correo "     ", contraseña "          ", nombre "    " | Mensaje de campo obligatorio en cada uno; un correo con espacios alrededor es válido | "Ingresa tu correo", "Ingresa tu contraseña", "Ingresa tu nombre completo"; null | Pasa |
| REQ-08 | Persistencia / consistencia | Una incidencia guardada se recupera idéntica al recargar | Reportar (prioridad Media) y recargar desde otro provider (otra sesión) | `toJson()` idéntico; ida y vuelta fromJson/toJson sin cambios | Mapas iguales | Pasa |
| REQ-09 | Persistencia / consistencia | El contador por estado coincide con la lista después de cambiar estados | 3 incidencias; admin pone una "En proceso" y otra "Resuelto" | {Pendiente:1, En proceso:1, Resuelto:1}; la suma es igual al total | {1, 1, 1}; suma 3 = 3 | Pasa |
| REQ-10 | Roles / permisos | Un usuario normal no puede ver todas ni cambiar el estado (mensaje de permisos) | Rol usuario: cargarTodas(); cambiarEstado(Resuelto) | Lista vacía; "No tienes permisos para esta acción"; el estado sigue Pendiente | Vacía; mensaje de permisos; Pendiente | Pasa |
| REQ-11 | Roles / permisos | Solo el administrador puede limpiar el historial (el agente es rechazado) | Rol agente: limpiarHistorial(); luego rol admin: limpiarHistorial() | Agente: mensaje de permisos y se conserva 1; admin: sin error y lista vacía | Rechazado (1 conservada) → vaciado | Pasa |
| REQ-12 | Manejo de errores | Un error del servidor muestra un mensaje genérico sin texto técnico | La API falla con 500 y texto SQL ("relation … violates constraint") | "No se pudo completar la operación. Intenta de nuevo"; no contiene "relation"; no se agrega nada; isGuardando=false | Mensaje genérico; sin texto técnico; lista vacía | Pasa |

## Evidencia de ejecución

```
00:00 +1: Operaciones principales REQ-01 ...
...
00:01 +11: Manejo de errores REQ-12 ...
00:05 +13: All tests passed!   (12 de caja negra + 1 widget_test del splash)
```
