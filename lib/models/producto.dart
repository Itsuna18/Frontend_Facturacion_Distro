class Producto {
  final int id;
  final String nombre;
  final double precio;
  final int stock;
  final String descripcion;
  final String imageURL;

  /// rowversion de SQL Server (columna Versions) en hexadecimal.
  /// Se usa para la concurrencia optimista al facturar.
  final String version;

  Producto({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.stock,
    this.descripcion = '',
    this.imageURL = '',
    this.version = '',
  });

  static double _aDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static int _aInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: _aInt(json['id']),
      nombre: json['nombre']?.toString() ?? '',
      precio: _aDouble(json['precio']),
      stock: _aInt(json['stock']),
      descripcion: json['descripcion']?.toString() ?? '',
      imageURL: (json['imagen_url'] ?? json['imageURL'] ?? '').toString(),
      version: json['version']?.toString() ?? '',
    );
  }
}
