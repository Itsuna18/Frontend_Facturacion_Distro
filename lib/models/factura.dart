double _aDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

int _aInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

class LineaFactura {
  final int id;
  final String nombre;
  final String descripcion;
  final String imagenUrl;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;
  final int stockRestante;

  LineaFactura({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.imagenUrl,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    required this.stockRestante,
  });

  factory LineaFactura.fromJson(Map<String, dynamic> json) => LineaFactura(
        id: _aInt(json['id']),
        nombre: json['nombre']?.toString() ?? '',
        descripcion: json['descripcion']?.toString() ?? '',
        imagenUrl: json['imagen_url']?.toString() ?? '',
        cantidad: _aInt(json['cantidad']),
        precioUnitario: _aDouble(json['precio_unitario']),
        subtotal: _aDouble(json['subtotal']),
        stockRestante: _aInt(json['stock_restante']),
      );
}

class Factura {
  final String numero;
  final String fecha;
  final String clienteNombre;
  final String clienteCedula;
  final String clienteCorreo;
  final String clienteDireccion;
  final List<LineaFactura> lineas;
  final double subtotal;
  final double iva;
  final double total;
  final String estado;
  final String xml;

  Factura({
    required this.numero,
    required this.fecha,
    required this.clienteNombre,
    required this.clienteCedula,
    required this.clienteCorreo,
    required this.clienteDireccion,
    required this.lineas,
    required this.subtotal,
    required this.iva,
    required this.total,
    required this.estado,
    required this.xml,
  });

  factory Factura.fromJson(Map<String, dynamic> json) {
    final cliente = (json['cliente'] as Map?)?.cast<String, dynamic>() ?? {};
    final totales = (json['totales'] as Map?)?.cast<String, dynamic>() ?? {};
    final productos = (json['productos'] as List?) ?? [];
    return Factura(
      numero: json['numero']?.toString() ?? '',
      fecha: json['fecha']?.toString() ?? '',
      clienteNombre: cliente['nombre']?.toString() ?? '',
      clienteCedula: cliente['cedula_ruc']?.toString() ?? '',
      clienteCorreo: cliente['correo']?.toString() ?? '',
      clienteDireccion: cliente['direccion']?.toString() ?? '',
      lineas: productos
          .map((p) => LineaFactura.fromJson((p as Map).cast<String, dynamic>()))
          .toList(),
      subtotal: _aDouble(totales['subtotal']),
      iva: _aDouble(totales['iva']),
      total: _aDouble(totales['total']),
      estado: json['estado']?.toString() ?? '',
      xml: json['xml']?.toString() ?? '',
    );
  }
}
