const express = require('express');
const disenosController = require('../controllers/disenos.controller');
const { verificarToken } = require('../middleware/auth');

const router = express.Router();

router.post('/', verificarToken, disenosController.crear);
router.get('/mios', verificarToken, disenosController.misDisenos);
router.get('/codigo/:codigo', disenosController.obtenerPorCodigo); // pública

module.exports = router;
