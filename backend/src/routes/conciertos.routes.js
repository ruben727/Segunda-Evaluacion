const express = require('express');
const conciertosController = require('../controllers/conciertos.controller');

const router = express.Router();

// Rutas públicas, no requieren autenticación.
router.get('/', conciertosController.listar);
router.get('/:id/estado', conciertosController.estado); // usado por la Smart TV (concierto + código + conectados)
router.get('/:id', conciertosController.obtenerPorId);

module.exports = router;
