import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data'; // <-- IMPORTANTE
import 'package:zentri_vendedor/config/api_config.dart';


class PdfService {
  static String get baseUrl => ApiConfig.instance.baseUrl;

  // ============================================================
  // DESCARGAR Y COMPARTIR FACTURA
  // ============================================================
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

      final List<int> pdfBytes = response.data as List<int>;
      final Uint8List uint8List = Uint8List.fromList(pdfBytes);
      final fileName = 'factura_$numeroFactura.pdf';

      await Share.shareXFiles(
        [
          XFile.fromData(
            uint8List,
            mimeType: 'application/pdf',
            name: fileName,
          ),
        ],
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

  // ============================================================
  // DESCARGAR Y COMPARTIR COTIZACIÓN
  // ============================================================
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

      final List<int> pdfBytes = response.data as List<int>;
      final Uint8List uint8List = Uint8List.fromList(pdfBytes);
      final fileName = 'cotizacion_$cotizacionId.pdf';

      await Share.shareXFiles(
        [
          XFile.fromData(
            uint8List,
            mimeType: 'application/pdf',
            name: fileName,
          ),
        ],
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

  // ============================================================
  // GENERAR PDF Y OBTENER BYTES (uso interno)
  // ============================================================
  static Future<Uint8List?> obtenerPDF(String endpoint, String token) async {
    try {
      final Dio dio = Dio();
      final response = await dio.get(
        '$baseUrl/api/$endpoint',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.bytes,
        ),
      );
      if (response.statusCode == 200) {
        final List<int> bytes = response.data as List<int>;
        return Uint8List.fromList(bytes);
      }
      return null;
    } catch (e) {
      print('❌ Error en obtenerPDF: $e');
      return null;
    }
  }
}