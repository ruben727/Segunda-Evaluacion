const express = require('express');
const { verificarToken } = require('../middleware/auth');
const usuarioModel = require('../models/usuario.model');

const router = express.Router();

router.get('/perfil', verificarToken, async (req, res, next) => {
  try {
    const usuario = await usuarioModel.buscarPorId(req.usuario.id);
    if (!usuario) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    res.json(usuario);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
