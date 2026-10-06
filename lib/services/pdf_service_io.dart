import 'package:zentri_vendedor/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';


class PdfService {
  static String get baseUrl => ApiConfig.instance.baseUrl;

  static Future<void> descargarYCompartirFactura(
    BuildContext context,
    String numeroFactura,
  ) async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token') ?? '';
      if (token.isEmpty) {
        throw Exception('No hay token de autenticación');
      }

      final Dio dio = Dio();
      if (kIsWeb) {
        dio.options.extra['withCredentials'] = false;
      }

      final response = await dio.get(
        '$baseUrl/api/factura_pdf/$numeroFactura',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.bytes,
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Error al generar PDF (código ${response.statusCode})');
      }

      final pdfBytes = response.data as List<int>;
      final fileName = 'factura_$numeroFactura.pdf';

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: '🧾 Factura $numeroFactura',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📄 PDF compartido'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error en descargarYCompartirFactura: $e');
      if (context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al generar PDF: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    }
  }

  static Future<void> descargarYCompartirCotizacion(
    BuildContext context,
    int cotizacionId,
  ) async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token') ?? '';
      if (token.isEmpty) {
        throw Exception('No hay token de autenticación');
      }

      final Dio dio = Dio();
      if (kIsWeb) {
        dio.options.extra['withCredentials'] = false;
      }

      final response = await dio.get(
        '$baseUrl/api/cotizacion_pdf/$cotizacionId',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.bytes,
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Error al generar PDF (código ${response.statusCode})');
      }

      final pdfBytes = response.data as List<int>;
      final fileName = 'cotizacion_$cotizacionId.pdf';

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: '📄 Cotización #$cotizacionId',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📄 PDF compartido'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error en descargarYCompartirCotizacion: $e');
      if (context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al generar PDF: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    }
  }

  static Future<List<int>?> obtenerPDF(String endpoint, String token) async {
    try {
      final Dio dio = Dio();
      if (kIsWeb) {
        dio.options.extra['withCredentials'] = false;
      }
      final response = await dio.get(
        '$baseUrl/api/$endpoint',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.bytes,
        ),
      );
      if (response.statusCode == 200) {
        return response.data as List<int>;
      }
      return null;
    } catch (e) {
      print('❌ Error en obtenerPDF: $e');
      return null;
    }
  }
}