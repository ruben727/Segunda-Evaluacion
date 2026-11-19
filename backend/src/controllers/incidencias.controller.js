const modelo = require('../models/incidencia.model');
const { esStaff } = require('../middleware/roles');

const ID_REGEX = /^\d+$/;
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const LIMITE_DEFECTO = 50;
const LIMITE_MAX = 200;
const SIN_PERMISO = 'No tienes permisos para esta acción';

function validarOpcion(valor, lista, campo) {
  if (valor === undefined || valor === null || valor === '') return `Selecciona ${campo}`;
  if (!lista.includes(valor)) return `Opción de ${campo} no válida`;
  return null;
}

/** POST /api/incidencias — cualquier usuario autenticado. */
async function crear(req, res, next) {
  try {
    const { tipo, equipo, prioridad } = req.body || {};
    const error = validarOpcion(tipo, modelo.TIPOS, 'tipo')
      || validarOpcion(equipo, modelo.EQUIPOS, 'equipo')
      || validarOpcion(prioridad, modelo.PRIORIDADES, 'prioridad');
    if (error) return res.status(400).json({ error });

    // Idempotency-Key opcional (UUID): un reintento con la misma clave no crea otra fila.
    const clave = req.get('Idempotency-Key') || null;
    if (clave && !UUID_REGEX.test(clave)) {
      return res.status(400).json({ error: 'Idempotency-Key debe ser un UUID' });
    }

    // creado_por y estado los fija el servidor; se ignora lo que mande el
    // cliente para que nadie cree tickets a nombre de otro.
    const { incidencia, nueva } = await modelo.crear({ tipo, equipo, prioridad, creadoPor: req.usuario.id, clave });
    if (!nueva) res.set('Idempotent-Replayed', 'true');
    res.status(201).json(incidencia);
  } catch (err) {
    next(err);
  }
}

/** ?limite=N (1-200, por defecto 50). */
function leerLimite(req) {
  const n = Number.parseInt(req.query.limite, 10);
  return Number.isInteger(n) && n > 0 ? Math.min(n, LIMITE_MAX) : LIMITE_DEFECTO;
}

/** GET /api/incidencias/mias — solo las del usuario autenticado (paginado). */
async function mias(req, res, next) {
  try {
    res.json(await modelo.listarDeUsuario(req.usuario.id, leerLimite(req)));
  } catch (err) {
    next(err);
  }
}

/** GET /api/incidencias — solo agente/admin (ver rutas), paginado. */
async function todas(req, res, next) {
  try {
    res.json(await modelo.listarTodas(leerLimite(req)));
  } catch (err) {
    next(err);
  }
}

/** GET /api/incidencias/resumen — conteo por estado (agente/admin). */
async function resumen(req, res, next) {
  try {
    res.json(await modelo.contarPorEstado());
  } catch (err) {
    next(err);
  }
}

/** GET /api/incidencias/agentes — para el selector de asignación. */
async function agentes(req, res, next) {
  try {
    res.json(await modelo.listarAgentes());
  } catch (err) {
    next(err);
  }
}

/** Busca la incidencia y comprueba que sea propia o que el rol sea staff. */
async function cargarIncidencia(req, res) {
  if (!ID_REGEX.test(req.params.id)) {
    res.status(400).json({ error: 'Parámetro con formato inválido' });
    return null;
  }
  const incidencia = await modelo.buscarPorId(req.params.id);
  if (!incidencia) {
    res.status(404).json({ error: 'Incidencia no encontrada' });
    return null;
  }
  const propia = String(incidencia.creado_por) === String(req.usuario.id);
  if (!propia && !esStaff(req.rol)) {
    res.status(403).json({ error: SIN_PERMISO });
    return null;
  }
  return incidencia;
}

/** GET /api/incidencias/:id — dueño o agente/admin. */
async function obtener(req, res, next) {
  try {
    const incidencia = await cargarIncidencia(req, res);
    if (incidencia) res.json(incidencia);
  } catch (err) {
    next(err);
  }
}

/**
 * PATCH /api/incidencias/:id
 *  - Dueño (usuario): solo puede cambiar tipo/equipo/prioridad de SU
 *    incidencia y mientras siga "Pendiente".
 *  - Agente/admin: además puede cambiar estado y agente_asignado.
 */
async function actualizar(req, res, next) {
  try {
    const incidencia = await cargarIncidencia(req, res);
    if (!incidencia) return;
    const staff = esStaff(req.rol);
    const body = req.body || {};
    const cambios = {};

    if (!staff && ('estado' in body || 'agente_asignado' in body)) {
      return res.status(403).json({ error: SIN_PERMISO });
    }
    if (!staff && incidencia.estado !== 'Pendiente') {
      return res.status(409).json({ error: 'Solo puedes editar incidencias pendientes' });
    }

    const listas = {
      tipo: modelo.TIPOS,
      equipo: modelo.EQUIPOS,
      prioridad: modelo.PRIORIDADES,
      estado: modelo.ESTADOS,
    };
    for (const [campo, lista] of Object.entries(listas)) {
      if (campo in body) {
        const error = validarOpcion(body[campo], lista, campo);
        if (error) return res.status(400).json({ error });
        cambios[campo] = body[campo];
      }
    }

    if ('agente_asignado' in body) {
      const id = body.agente_asignado;
      if (id === null) {
        cambios.agente_asignado = null;
      } else {
        const validos = await modelo.listarAgentes();
        if (!validos.some((a) => String(a.id) === String(id))) {
          return res.status(400).json({ error: 'El agente seleccionado no es válido' });
        }
        cambios.agente_asignado = Number(id);
      }
    }

    if (Object.keys(cambios).length === 0) {
      return res.status(400).json({ error: 'No hay cambios que guardar' });
    }

    res.json(await modelo.actualizar(incidencia.id, cambios));
  } catch (err) {
    next(err);
  }
}

/** DELETE /api/incidencias — limpia el historial de pruebas (solo admin). */
async function limpiar(req, res, next) {
  try {
    const eliminadas = await modelo.eliminarTodas();
    res.json({ eliminadas });
  } catch (err) {
    next(err);
  }
}

module.exports = { crear, mias, todas, resumen, agentes, obtener, actualizar, limpiar };
