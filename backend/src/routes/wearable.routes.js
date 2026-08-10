const express = require('express');
const wearableController = require('../controllers/wearable.controller');
const { verificarToken } = require('../middleware/auth');

const router = express.Router();

router.post('/datos', verificarToken, wearableController.registrarDato);
router.get('/ultimos/:userId', verificarToken, wearableController.ultimos);

// Puente público (sin auth) para simular la sincronización BLE cuando el
// teléfono y el reloj corren en emuladores separados (ver comentario en
// wearable.controller.js).
router.post('/simulacion', wearableController.actualizarSimulacion);
router.get('/simulacion', wearableController.obtenerSimulacion);

// Puente en dirección teléfono → reloj: "reproducir esta canción con
// este color X segundos" (ver comentario en wearable.controller.js).
router.post('/comando', wearableController.enviarComando);
router.post('/comando/detener', wearableController.detenerComando);
router.get('/comando', wearableController.obtenerComando);

module.exports = router;
