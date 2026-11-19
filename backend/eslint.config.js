// Configuración ESLint agregada para la Práctica 11 (análisis estático).
const js = require('@eslint/js');
const globals = require('globals');
module.exports = [
  { ignores: ['node_modules/**', 'coverage/**', '.vercel/**'] },
  js.configs.recommended,
  {
    files: ['**/*.js'],
    languageOptions: { ecmaVersion: 2022, sourceType: 'commonjs', globals: { ...globals.node, ...globals.jest } },
    rules: { 'no-console': 'warn', eqeqeq: 'error', 'no-unused-vars': 'warn', 'require-await': 'warn', 'no-return-await': 'warn' },
  },
];
