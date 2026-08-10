const wearableModel = require('../models/wearable.model');

// Último estado simulado reportado por el reloj (en memoria, sin auth).
// Sirve de "puente" para que el teléfono vea los mismos datos falsos que
// el wearable cuando ambos corren en emuladores separados y no pueden
// verse por BLE real (los emuladores de Android no emulan radio
// Bluetooth entre sí). En hardware físico, el teléfono recibe estos
// mismos datos por NOTIFY vía BLE real (ver ble_service.dart) y este
// puente HTTP es simplemente redundante.
let ultimaSimulacion = null;

// Comando activo mandado por el teléfono ("reproducir esta canción con
// este color"), que el reloj consulta por polling para saber qué color
// mostrar. Es el puente en la dirección contraria a `ultimaSimulacion`.
let comandoActivo = null;

async function registrarDato(req, res, next) {
  try {
    const { ritmo, oxigeno, efecto_color, vibracion, diseno_id } = req.body;

    if (ritmo === undefined || !efecto_color) {
      return res.status(400).json({ error: 'ritmo y efecto_color son obligatorios' });
    }

    await wearableModel.guardarDato({
      usuarioId: req.usuario.id,
      diseno_id,
      ritmo,
      oxigeno,
      efecto_color,
      vibracion,
    });

    res.status(201).json({ success: true });
  } catch (err) {
    next(err);
  }
}

async function ultimos(req, res, next) {
  try {
    // Un usuario solo puede consultar sus propios datos.
    if (String(req.usuario.id) !== String(req.params.userId)) {
      return res.status(403).json({ error: 'No autorizado para ver estos datos' });
    }
    const datos = await wearableModel.ultimos(req.params.userId, 60);
    res.json(datos);
  } catch (err) {
    next(err);
  }
}

// POST público: el reloj publica aquí cada lectura simulada (sin login).
async function actualizarSimulacion(req, res, next) {
  try {
    const { ritmo, oxigeno, efecto_color, vibracion } = req.body;

    if (ritmo === undefined || !efecto_color) {
      return res.status(400).json({ error: 'ritmo y efecto_color son obligatorios' });
    }

    ultimaSimulacion = {
      ritmo,
      oxigeno: oxigeno ?? null,
      efecto_color,
      vibracion: !!vibracion,
      actualizado_en: new Date().toISOString(),
    };

    res.json({ success: true });
  } catch (err) {
    next(err);
  }
}

// GET público: el teléfono consulta aquí el último dato falso del reloj.
async function obtenerSimulacion(req, res, next) {
  try {
    res.json(ultimaSimulacion);
  } catch (err) {
    next(err);
  }
}

// POST público: el teléfono manda "muestra este color X segundos" (al
// darle Iniciar a una canción). El reloj lo consulta por polling.
async function enviarComando(req, res, next) {
  try {
    const { color_hex, duracion_seg, cancion_titulo } = req.body;

    if (!color_hex || duracion_seg === undefined) {
      return res.status(400).json({ error: 'color_hex y duracion_seg son obligatorios' });
    }

    comandoActivo = {
      color_hex,
      duracion_seg,
      cancion_titulo: cancion_titulo || null,
      activo: true,
      iniciado_en: new Date().toISOString(),
    };

    res.json({ success: true });
  } catch (err) {
    next(err);
  }
}

// POST público: "quitar" — el teléfono detiene la reproducción antes de
// tiempo, o la canción terminó su cuenta regresiva.
async function detenerComando(req, res, next) {
  try {
    comandoActivo = null;
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
}

// GET público: el reloj consulta aquí si hay un color activo que mostrar.
async function obtenerComando(req, res, next) {
  try {
    res.json(comandoActivo || { activo: false });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  registrarDato,
  ultimos,
  actualizarSimulacion,
  obtenerSimulacion,
  enviarComando,
  detenerComando,
  obtenerComando,
};
