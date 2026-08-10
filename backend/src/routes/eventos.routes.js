const express = require('express');
const eventosController = require('../controllers/eventos.controller');
const { verificarToken } = require('../middleware/auth');

const router = express.Router();

router.post('/unirse', verificarToken, eventosController.unirse);
router.get('/mios', verificarToken, eventosController.misEventos);

// Pública: la Smart TV no inicia sesión, solo consulta el conteo en vivo.
router.get('/conectados', eventosController.conectados);

module.exports = router;
