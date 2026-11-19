const express = require('express');
const busquedaController = require('../controllers/busqueda.controller');
const { verificarToken } = require('../middleware/auth');
const { cargarRol, requiereRol } = require('../middleware/roles');

const router = express.Router();

// Públicas: buscan sobre los mismos datos que GET /conciertos.
router.get('/', busquedaController.buscar);
router.get('/estado', busquedaController.estado);

// Solo admin: recarga el índice de Elasticsearch desde PostgreSQL.
router.post('/reindexar', verificarToken, cargarRol, requiereRol('admin'), busquedaController.reindexar);

module.exports = router;
