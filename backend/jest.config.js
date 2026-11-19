// Configuración Jest agregada para la Práctica 11 (caja blanca del backend).
module.exports = {
  testEnvironment: 'node',
  roots: ['<rootDir>/test'],
  collectCoverageFrom: ['src/**/*.js', '!src/services/elasticsearch.service.js', '!src/ws/**'],
  coverageReporters: ['text', 'text-summary', 'html', 'lcov', 'json-summary'],
  coverageDirectory: 'coverage',
};
