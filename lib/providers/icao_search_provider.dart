// ignore_for_file: dangling_library_doc_comments
// Contém código gerado por IA

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/aisweb_api_service.dart';

/// IcaoSearchState
/// Representa o estado da busca de cartas por ICAO.
class IcaoSearchState {
  final List<Map<String, String>> charts;
  final bool isLoading;
  final String? error;
  final String lastQuery;

  IcaoSearchState({
    this.charts = const [],
    this.isLoading = false,
    this.error,
    this.lastQuery = '',
  });

  IcaoSearchState copyWith({
    List<Map<String, String>>? charts,
    bool? isLoading,
    String? error,
    String? lastQuery,
  }) {
    return IcaoSearchState(
      charts: charts ?? this.charts,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Se for null, limpa o erro
      lastQuery: lastQuery ?? this.lastQuery,
    );
  }
}

/// IcaoSearchNotifier
/// Gerencia a lógica de busca de cartas consumindo o AiswebApiService.
class IcaoSearchNotifier extends Notifier<IcaoSearchState> {
  final _apiService = AiswebApiService();

  @override
  IcaoSearchState build() {
    return IcaoSearchState();
  }

  /// Realiza a busca de cartas para o ICAO fornecido.
  Future<void> search(String icao) async {
    if (icao.isEmpty) return;
    
    final query = icao.toUpperCase().trim();
    if (query == state.lastQuery && state.charts.isNotEmpty) return;

    state = state.copyWith(isLoading: true, error: null, lastQuery: query);

    try {
      final results = await _apiService.getChartsForIcao(query);
      state = state.copyWith(
        charts: results,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceAll('Exception: ', ''),
        isLoading: false,
        charts: [],
      );
    }
  }

  /// Limpa os resultados da busca.
  void clear() {
    state = IcaoSearchState();
  }
}

/// Provider global para busca de ICAO.
final icaoSearchProvider = NotifierProvider<IcaoSearchNotifier, IcaoSearchState>(
  IcaoSearchNotifier.new,
);
