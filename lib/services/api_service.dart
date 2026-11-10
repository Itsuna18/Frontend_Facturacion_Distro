import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/factura.dart';
import '../models/item_carrito.dart';
import '../models/producto.dart';

/// Se lanza cuando la API responde 409: otro cliente modificó el producto
/// (concurrencia optimista) o ya no hay stock suficiente.
class ConflictoException implements Exception {
  final String mensaje;
  final String motivo;
  final Producto? productoActual;

  ConflictoException(this.mensaje, this.motivo, this.productoActual);

  @override
  String toString() => mensaje;
}

class ApiService {
  static const String baseUrl = "http://localhost:5000";

  Future<List<Producto>> obtenerProductos() async {
    final url = Uri.parse("$baseUrl/api/productos");
    final response = await http.get(url);
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(body);
      return data
          .map((item) => Producto.fromJson((item as Map).cast<String, dynamic>()))
          .toList();
    }
    throw Exception(
      "Error ${response.statusCode}: No se pudieron obtener los productos. $body",
    );
  }

  Future<Factura> generarFactura(List<ItemCarrito> carrito) async {
    final url = Uri.parse("$baseUrl/api/facturas");
    final hoy = DateTime.now();
    final fecha = "${hoy.year.toString().padLeft(4, '0')}-"
        "${hoy.month.toString().padLeft(2, '0')}-"
        "${hoy.day.toString().padLeft(2, '0')}";

    final datosCompra = {
      // el número lo genera la API para que dos clientes no se pisen
      "fecha": fecha,
      "cliente": {
        "nombre": "Ana López",
        "cedula_ruc": "1804567890",
        "correo": "ana@email.com",
        "direccion": "Ambato, Ecuador",
      },
      "productos": carrito.map((item) => item.toJsonFactura()).toList(),
    };

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode(datosCompra),
    );
    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode == 200) {
      return Factura.fromJson(jsonDecode(body) as Map<String, dynamic>);
    }

    if (response.statusCode == 409) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final prod = data['producto'];
      throw ConflictoException(
        data['error']?.toString() ?? "Conflicto de concurrencia",
        data['motivo']?.toString() ?? "concurrencia",
        prod is Map ? Producto.fromJson(prod.cast<String, dynamic>()) : null,
      );
    }

    throw Exception("Error ${response.statusCode}: $body");
  }
}
