/// Representa una lectura recibida por BLE NOTIFY desde el reloj:
/// ritmo (BPM), oxígeno en sangre (SpO2 %), calorías quemadas acumuladas
/// en la sesión, color de efecto activo y estado de vibración.
class WearableData {
  final int ritmo;
  final int oxigeno;
  final int? calorias;
  final String colorHex;
  final bool vibracion;
  final DateTime timestamp;

  WearableData({
    required this.ritmo,
    this.oxigeno = 98,
    this.calorias,
    required this.colorHex,
    required this.vibracion,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get esAlertaAlta => ritmo > 100;
}
