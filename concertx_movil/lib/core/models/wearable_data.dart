/// Representa una lectura recibida por BLE NOTIFY desde el reloj:
/// ritmo (BPM), oxígeno en sangre (SpO2 %), color de efecto activo y
/// estado de vibración.
class WearableData {
  final int ritmo;
  final int oxigeno;
  final String colorHex;
  final bool vibracion;
  final DateTime timestamp;

  WearableData({
    required this.ritmo,
    this.oxigeno = 98,
    required this.colorHex,
    required this.vibracion,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get esAlertaAlta => ritmo > 100;
}
