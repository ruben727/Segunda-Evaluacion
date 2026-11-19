const express = require('express');
const c = require('../controllers/incidencias.controller');
const { verificarToken } = require('../middleware/auth');
const { cargarRol, requiereRol } = require('../middleware/roles');

const router = express.Router();

// Todas las rutas exigen sesión y cargan el rol real desde la BD. Los
// permisos se validan AQUÍ (servidor), no solo ocultando botones en la app.
router.use(verificarToken, cargarRol);

router.post('/', c.crear);
router.get('/mias', c.mias);
router.get('/', requiereRol('agente', 'admin'), c.todas);
router.get('/resumen', requiereRol('agente', 'admin'), c.resumen);
router.get('/agentes', requiereRol('agente', 'admin'), c.agentes);
router.delete('/', requiereRol('admin'), c.limpiar);
router.get('/:id', c.obtener);
router.patch('/:id', c.actualizar);

module.exports = router;
