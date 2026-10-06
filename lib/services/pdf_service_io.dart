import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:zentri_vendedor/config/api_config.dart';
import 'package:zentri_vendedor/services/api_dio.dart';


class PdfService {
  static String get baseUrl => ApiConfig.instance.baseUrl;

  static Future<void> descargarYCompartirFactura(
    BuildContext context,
    String numeroFactura,
  ) async {
    try {
      // Dio compartido: ya inyecta el token y detecta el 401.
      final response = await ApiDio.instance.get(
        '$baseUrl/api/factura_pdf/$numeroFactura',
        options: Options(
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
      // Dio compartido: ya inyecta el token y detecta el 401.
      final response = await ApiDio.instance.get(
        '$baseUrl/api/cotizacion_pdf/$cotizacionId',
        options: Options(
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
      // Dio compartido: ya inyecta el token por defecto.
      // El parámetro `token` se conserva por compatibilidad de firma.
      final response = await ApiDio.instance.get(
        '$baseUrl/api/$endpoint',
        options: Options(
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