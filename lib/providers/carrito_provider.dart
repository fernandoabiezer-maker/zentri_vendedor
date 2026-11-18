import 'package:flutter/material.dart';
import 'package:zentri_vendedor/models/item_carrito.dart';
import 'package:zentri_vendedor/models/cliente.dart';
import 'package:zentri_vendedor/models/item_cotizacion.dart';

class CarritoProvider extends ChangeNotifier {
  List<ItemCarrito> _items = [];
  Cliente? _clienteSeleccionado;
  String? _metodoPago;
  String? _tipoVenta;
  String? _referencia;
  int? _diasCredito;

  List<ItemCarrito> get items => _items;
  Cliente? get clienteSeleccionado => _clienteSeleccionado;
  String? get metodoPago => _metodoPago;
  String? get tipoVenta => _tipoVenta;
  String? get referencia => _referencia;
  int? get diasCredito => _diasCredito;

  double get totalUsd {
    double total = 0;
    for (var item in _items) {
      total += item.subtotal;
    }
    return total;
  }

  // Ahora es double porque cantidad es double.
  double get totalItems {
    double count = 0;
    for (var item in _items) {
      count += item.cantidad;
    }
    return count;
  }

  // Representación corta del total de items para el badge del carrito
  // (sin decimales si es entero, sin ceros sobrantes si es fraccionario).
  String get totalItemsLabel {
    final t = totalItems;
    if (t == t.roundToDouble()) return t.toInt().toString();
    String s = t.toStringAsFixed(3);
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  int get itemCount => _items.length;

  void agregarProducto({
    required int productoId,
    required String nombre,
    required String codigo,
    required double precio,
    double? precioBase,
    String? imagen,
    double cantidad = 1.0,
  }) {
    final index = _items.indexWhere((item) => item.productoId == productoId);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(
        cantidad: _items[index].cantidad + cantidad,
      );
    } else {
      _items.add(ItemCarrito(
        productoId: productoId,
        nombre: nombre,
        codigo: codigo,
        precio: precio,
        precioBase: precioBase,
        imagen: imagen,
        cantidad: cantidad,
      ));
    }
    notifyListeners();
  }

  void actualizarCantidad(int productoId, double nuevaCantidad) {
    final index = _items.indexWhere((item) => item.productoId == productoId);
    if (index >= 0) {
      if (nuevaCantidad < 0.001) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(cantidad: nuevaCantidad);
      }
      notifyListeners();
    }
  }

  void eliminarProducto(int productoId) {
    _items.removeWhere((item) => item.productoId == productoId);
    notifyListeners();
  }

  void vaciarCarrito() {
    _items.clear();
    _clienteSeleccionado = null;
    _metodoPago = null;
    _tipoVenta = null;
    _referencia = null;
    _diasCredito = null;
    notifyListeners();
  }

  void setCliente(Cliente cliente) {
    _clienteSeleccionado = cliente;
    notifyListeners();
  }

  void limpiarCliente() {
    _clienteSeleccionado = null;
    notifyListeners();
  }

  void setMetodoPago(String metodo, {String? referencia, String? tipoVenta, int? diasCredito}) {
    _metodoPago = metodo;
    _referencia = referencia;
    _tipoVenta = tipoVenta;
    _diasCredito = diasCredito;
    notifyListeners();
  }

  void limpiarDatosCheckout() {
    // Método para limpiar datos de checkout si es necesario
  }

  // ============================================================
  // CARGAR ITEMS DESDE UNA COTIZACIÓN (PARA EDICIÓN)
  // ============================================================
  void cargarItemsDesdeCotizacion(List<ItemCotizacion> items) {
    _items.clear();
    for (var item in items) {
      _items.add(ItemCarrito(
        productoId: item.id,
        nombre: item.nombre,
        codigo: item.codigo,
        precio: item.precioUnitario,
        precioBase: item.precioBase,
        imagen: item.imagen,
        cantidad: item.cantidad,
      ));
    }
    notifyListeners();
  }
}