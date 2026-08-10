// UUIDs compartidos entre concertx_movil y concertx_wearable.
// IMPORTANTE: deben coincidir EXACTAMENTE en ambos proyectos.

const String concertxServiceUuid = "12345678-1234-1234-1234-123456789abc";
const String ritmoCharUuid = "12345678-1234-1234-1234-123456789ab1";
const String colorCharUuid = "12345678-1234-1234-1234-123456789ab2";
const String vibracionCharUuid = "12345678-1234-1234-1234-123456789ab3";
const String oxigenoCharUuid = "12345678-1234-1234-1234-123456789ab4";

// Nombre local que anuncia el reloj para que el teléfono pueda encontrarlo.
const String wearableDeviceName = "ConcertX-Wearable";

// Umbral de BPM a partir del cual se muestra la alerta de "alta energía".
const int umbralBpmAlerta = 100;

// Rango normal de oxígeno en sangre (SpO2); por debajo de esto se
// considera baja saturación.
const int umbralOxigenoBajo = 95;
