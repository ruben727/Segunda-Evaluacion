import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/services/widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX');
  // Si la app se abrió tocando el widget, recordar a qué concierto ir.
  await WidgetService.revisarAperturaDesdeWidget();
  runApp(const ConcertxApp());
}
