import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:xml/xml.dart';

class AiswebApiService {
  static const String _baseUrl = 'https://aisweb.decea.mil.br/api/';

  /// Fetches a list of charts for a given ICAO code.
  Future<List<Map<String, String>>> getChartsForIcao(String icao) async {
    final apiKey = dotenv.env['AISWEB_API_KEY'];
    final apiPass = dotenv.env['AISWEB_API_PASS'];

    if (apiKey == null || apiPass == null) {
      throw Exception('AISWEB API credentials not found in .env');
    }

    final uri = Uri.parse('$_baseUrl?apiKey=$apiKey&apiPass=$apiPass&area=cartas&icaocode=$icao');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        
        List<Map<String, String>> charts = [];
        
        for (var item in items) {
          final id = item.findElements('id').firstOrNull?.innerText ?? '';
          final tipo = item.findElements('tipo').firstOrNull?.innerText ?? '';
          final nome = item.findElements('nome').firstOrNull?.innerText ?? '';
          final link = item.findElements('link').firstOrNull?.innerText ?? '';
          final dt = item.findElements('dt').firstOrNull?.innerText ?? '';
          
          if (link.isNotEmpty) {
            charts.add({
              'id': id,
              'tipo': tipo, // e.g., IAC, SID, STAR
              'nome': nome, // e.g., ILS R RWY 10R
              'link': link, // download URL
              'data': dt,
            });
          }
        }
        
        return charts;
      } else {
        throw Exception('Failed to load charts. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching charts: $e');
    }
  }
}

