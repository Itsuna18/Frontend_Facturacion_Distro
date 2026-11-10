import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:techstore_carrito/models/factura.dart';
import 'package:techstore_carrito/models/item_carrito.dart';
import 'package:techstore_carrito/models/producto.dart';
import 'package:techstore_carrito/services/api_service.dart';

class CarritoPage extends StatefulWidget {
  const CarritoPage({super.key});

  @override
  State<CarritoPage> createState() => _CarritoPageState();
}

class _CarritoPageState extends State<CarritoPage> {
  final ApiService apiService = ApiService();
  List<Producto> productos = [];
  List<ItemCarrito> carrito = [];
  bool cargandoProductos = true;
  bool generandoFactura = false;
  Factura? factura;
  String mensajeError = "";
  Timer? _refresco;

  @override
  void initState() {
    super.initState();
    cargarProductos();
    // Refresca el stock cada 5 s para ver lo que compra el otro cliente
    _refresco = Timer.periodic(
      const Duration(seconds: 5),
      (_) => cargarProductos(silencioso: true),
    );
  }

  @override
  void dispose() {
    _refresco?.cancel();
    super.dispose();
  }

  Future<void> cargarProductos({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        cargandoProductos = true;
        mensajeError = "";
      });
    }
    try {
      final data = await apiService.obtenerProductos();
      if (!mounted) return;
      setState(() {
        productos = data;
        cargandoProductos = false;
      });
    } catch (e) {
      if (!mounted || silencioso) return;
      setState(() {
        mensajeError = e.toString();
        cargandoProductos = false;
      });
    }
  }

  /// Muestra un solo mensaje a la vez: reemplaza el anterior en lugar de
  /// apilarlos (evita la cola de avisos al presionar muchas veces).
  void _mensaje(String texto, {Color? color}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// true cuando en el carrito ya está todo el stock disponible.
  bool limiteAlcanzado(int id) =>
      cantidadEnCarrito(id) >= stockDisponible(id);

  void _avisarLimite(String nombre) {
    _mensaje(
      "Llegaste al límite de stock de $nombre. Solo puedes quitar o eliminar.",
      color: Colors.orange.shade800,
    );
  }

  void agregarAlCarrito(Producto producto) {
    if (limiteAlcanzado(producto.id)) return; // el botón ya está bloqueado
    final index = carrito.indexWhere((item) => item.producto.id == producto.id);
    setState(() {
      if (index >= 0) {
        carrito[index].cantidad++;
      } else {
        carrito.add(ItemCarrito(producto: producto));
      }
      mensajeError = "";
    });
    if (limiteAlcanzado(producto.id)) _avisarLimite(producto.nombre);
  }

  /// Stock más reciente leído de la BD (se refresca cada 5 s).
  int stockDisponible(int id) {
    for (final p in productos) {
      if (p.id == id) return p.stock;
    }
    return 0;
  }

  int cantidadEnCarrito(int id) {
    for (final i in carrito) {
      if (i.producto.id == id) return i.cantidad;
    }
    return 0;
  }

  /// Fija la cantidad escrita a mano (o con +/-) validando el stock.
  void cambiarCantidad(ItemCarrito item, int nueva) {
    final stock = stockDisponible(item.producto.id);
    if (nueva > stock) nueva = stock;
    if (nueva == item.cantidad) return;
    setState(() {
      if (nueva <= 0) {
        carrito.remove(item);
      } else {
        item.cantidad = nueva;
      }
      mensajeError = "";
    });
    if (nueva > 0 && nueva >= stock) _avisarLimite(item.producto.nombre);
  }

  void quitarDelCarrito(ItemCarrito item) {
    final index =
        carrito.indexWhere((e) => e.producto.id == item.producto.id);
    if (index == -1) return;
    setState(() {
      if (carrito[index].cantidad > 1) {
        carrito[index].cantidad--;
      } else {
        carrito.removeAt(index);
      }
      mensajeError = "";
    });
  }

  void limpiarCarrito() {
    setState(() {
      carrito.clear();
      factura = null;
      mensajeError = "";
    });
  }

  double get subtotal =>
      carrito.fold(0.0, (total, item) => total + item.subtotal);
  double get iva => subtotal * 0.15;
  double get total => subtotal + iva;

  /// Tras un conflicto: actualiza el carrito con los datos recién leídos
  /// (nueva versión y stock) para que el usuario decida si reintenta.
  void _sincronizarCarrito() {
    final porId = {for (final p in productos) p.id: p};
    final nuevo = <ItemCarrito>[];
    for (final item in carrito) {
      final p = porId[item.producto.id];
      if (p == null || p.stock <= 0) continue;
      item.producto = p;
      if (item.cantidad > p.stock) item.cantidad = p.stock;
      nuevo.add(item);
    }
    carrito = nuevo;
  }

  Future<void> generarFactura() async {
    if (carrito.isEmpty) {
      setState(() {
        mensajeError = "Debe ingresar al menos un producto";
        factura = null;
      });
      return;
    }
    setState(() {
      generandoFactura = true;
      factura = null;
      mensajeError = "";
    });

    try {
      final respuesta = await apiService.generarFactura(carrito);
      if (!mounted) return;
      setState(() {
        factura = respuesta;
        carrito.clear();
      });
      _mensaje("Factura ${respuesta.numero} generada", color: Colors.green);
      await cargarProductos(silencioso: true);
    } on ConflictoException catch (e) {
      await cargarProductos(silencioso: true);
      if (!mounted) return;
      setState(() {
        mensajeError = "⚠ Conflicto de concurrencia: ${e.mensaje}";
        _sincronizarCarrito();
      });
      _mensaje(e.mensaje, color: Colors.orange.shade800);
    } catch (e) {
      if (!mounted) return;
      setState(() => mensajeError = e.toString());
    } finally {
      if (mounted) setState(() => generandoFactura = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("TechStore 360 - Carrito SOA"),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Recargar productos",
            icon: const Icon(Icons.refresh),
            onPressed: () => cargarProductos(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 850) return _vistaMovil();
          return Row(
            children: [
              Expanded(flex: 2, child: _panelProductos()),
              Expanded(flex: 2, child: _panelCarrito()),
              Expanded(flex: 3, child: _panelFactura()),
            ],
          );
        },
      ),
    );
  }

  Widget _vistaMovil() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 380, child: _panelProductos()),
          SizedBox(height: 380, child: _panelCarrito()),
          SizedBox(height: 560, child: _panelFactura()),
        ],
      ),
    );
  }

  Widget _imagen(String url, {double size = 45}) {
    if (url.isEmpty) return Icon(Icons.devices, size: size * 0.7);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            Icon(Icons.image_not_supported, size: size * 0.7),
      ),
    );
  }

  Widget _panelProductos() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Productos desde la BD",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (cargandoProductos)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (mensajeError.isNotEmpty && productos.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(mensajeError, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => cargarProductos(),
                      child: const Text("Reintentar"),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: productos.length,
                itemBuilder: (context, index) {
                  final producto = productos[index];
                  return Card(
                    child: ListTile(
                      leading: _imagen(producto.imageURL),
                      title: Text(producto.nombre),
                      subtitle: Text(
                        "Precio: \$${producto.precio.toStringAsFixed(2)}"
                        " | ${producto.stock > 0 ? "Stock: ${producto.stock}" : "AGOTADO"}"
                        "${cantidadEnCarrito(producto.id) > 0 ? " | En carrito: ${cantidadEnCarrito(producto.id)}" : ""}",
                        style: TextStyle(
                          color: producto.stock > 0 ? null : Colors.red,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_shopping_cart),
                        tooltip: limiteAlcanzado(producto.id)
                            ? "Límite de stock alcanzado"
                            : "Agregar al carrito",
                        onPressed: limiteAlcanzado(producto.id) ||
                                generandoFactura
                            ? null
                            : () => agregarAlCarrito(producto),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _panelCarrito() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Carrito de compras",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: carrito.isEmpty
                ? const Center(child: Text("No hay productos en el carrito."))
                : ListView.builder(
                    itemCount: carrito.length,
                    itemBuilder: (context, index) {
                      final item = carrito[index];
                      final stock = stockDisponible(item.producto.id);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _imagen(item.producto.imageURL, size: 40),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.producto.nombre,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          "\$${item.producto.precio.toStringAsFixed(2)} c/u"
                                          " | Disponible: $stock",
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "\$${item.subtotal.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: "Quitar uno",
                                    icon:
                                        const Icon(Icons.remove_circle_outline),
                                    onPressed: () => quitarDelCarrito(item),
                                  ),
                                  _CantidadEditor(
                                    key: ValueKey(item.producto.id),
                                    cantidad: item.cantidad,
                                    maximo: stock,
                                    onCambio: (n) => cambiarCantidad(item, n),
                                  ),
                                  IconButton(
                                    tooltip: item.cantidad >= stock
                                        ? "Límite de stock alcanzado"
                                        : "Agregar uno",
                                    icon: const Icon(Icons.add_circle_outline),
                                    // bloqueado al llegar al stock
                                    onPressed: item.cantidad >= stock
                                        ? null
                                        : () => cambiarCantidad(
                                            item, item.cantidad + 1),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: "Eliminar del carrito",
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () =>
                                        setState(() => carrito.remove(item)),
                                  ),
                                ],
                              ),
                              if (item.cantidad > stock)
                                Text(
                                  stock == 0
                                      ? "Otro cliente compró todo el stock"
                                      : "Solo quedan $stock (otro cliente compró)",
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 12),
                                )
                              else if (item.cantidad == stock)
                                Text(
                                  "Límite de stock alcanzado ($stock)",
                                  style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(),
          Text("Subtotal: \$${subtotal.toStringAsFixed(2)}"),
          Text("IVA 15%: \$${iva.toStringAsFixed(2)}"),
          Text(
            "Total: \$${total.toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: generandoFactura ? null : generarFactura,
                  icon: const Icon(Icons.receipt_long),
                  label: Text(
                    generandoFactura ? "Generando..." : "Generar factura",
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: generandoFactura ? null : limpiarCarrito,
                icon: const Icon(Icons.delete),
                tooltip: "Limpiar carrito",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _panelFactura() {
    final f = factura;
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blueGrey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Factura XML",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (mensajeError.isNotEmpty && productos.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                mensajeError,
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ),
          Expanded(
            child: f == null
                ? const Center(
                    child: Text(
                      "Aquí aparecerá la factura XML generada por el servicio REST...",
                      textAlign: TextAlign.center,
                    ),
                  )
                : _vistaXml(f),
          ),
        ],
      ),
    );
  }

  Widget _vistaXml(Factura f) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          f.xml,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: "monospace",
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Campo numérico para escribir la cantidad directamente.
/// Se confirma con Enter o al salir del campo.
class _CantidadEditor extends StatefulWidget {
  final int cantidad;
  final int maximo;
  final ValueChanged<int> onCambio;

  const _CantidadEditor({
    super.key,
    required this.cantidad,
    required this.maximo,
    required this.onCambio,
  });

  @override
  State<_CantidadEditor> createState() => _CantidadEditorState();
}

class _CantidadEditorState extends State<_CantidadEditor> {
  late final TextEditingController _ctrl =
      TextEditingController(text: "${widget.cantidad}");
  final FocusNode _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    _foco.addListener(() {
      if (!_foco.hasFocus) _confirmar();
    });
  }

  @override
  void didUpdateWidget(covariant _CantidadEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cantidad != oldWidget.cantidad) {
      _ctrl.text = "${widget.cantidad}";
    }
  }

  void _confirmar() {
    final n = int.tryParse(_ctrl.text.trim());
    if (n == null) {
      _ctrl.text = "${widget.cantidad}";
      return;
    }
    if (n != widget.cantidad) {
      widget.onCambio(n);
    }
    // tras reconstruir, mostrar el valor final (p. ej. si se ajustó al stock)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.text = "${widget.cantidad}";
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: TextField(
        controller: _ctrl,
        focusNode: _foco,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          // no más dígitos de los que tiene el stock (stock 15 -> 2 dígitos)
          LengthLimitingTextInputFormatter(
            widget.maximo < 1 ? 1 : "${widget.maximo}".length,
          ),
          _TopeFormatter(widget.maximo),
        ],
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        onSubmitted: (_) => _confirmar(),
      ),
    );
  }
}

/// Si se escribe un número mayor al stock, lo reemplaza por el máximo.
class _TopeFormatter extends TextInputFormatter {
  final int maximo;
  _TopeFormatter(this.maximo);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final n = int.tryParse(newValue.text);
    if (n == null || n <= maximo) return newValue;
    final texto = "$maximo";
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
