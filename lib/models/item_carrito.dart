import 'package:techstore_carrito/models/producto.dart';

class ItemCarrito {
  /// Producto tal como se leyó al agregarlo (incluye su versión).
  Producto producto;
  int cantidad;

  ItemCarrito({
    required this.producto,
    this.cantidad = 1,
  });

  double get subtotal => producto.precio * cantidad;

  Map<String, dynamic> toJsonFactura() {
    return {
      "id": producto.id,
      "nombre": producto.nombre,
      "cantidad": cantidad,
      "precio_unitario": producto.precio,
      // versión que vio este cliente: si otro la cambió, la API responde 409
      "version": producto.version,
    };
  }
}
