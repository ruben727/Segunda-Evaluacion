import 'package:flutter/foundation.dart';
import '../models/concierto.dart';
import '../services/api_service.dart';

class ConciertoProvider extends ChangeNotifier {
  final ApiService _apiService;

  ConciertoProvider({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  List<Concierto> conciertos = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> fetchConciertos() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      conciertos = await _apiService.getConciertos();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  List<Concierto> searchConciertos(String query) {
    if (query.trim().isEmpty) return conciertos;
    final q = query.toLowerCase();
    return conciertos.where((c) {
      return c.artista.toLowerCase().contains(q) ||
          (c.estadio?.nombre.toLowerCase().contains(q) ?? false) ||
          (c.estadio?.ciudad?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
}
