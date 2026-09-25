/// Dinero del instalador (fase 5): pagos, catálogo y cotizaciones.
/// Contrato: `/v1/instalador/pagos`, `/catalogo`, `/cotizaciones`.
/// En Odoo: factura de proveedor (Compras), productos etiquetados
/// «App instalador» (Ventas) y órdenes de venta atribuidas al instalador.
library;

String _s(dynamic v) => v?.toString() ?? '';
double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

class Pago {
  final String id;
  final String referencia; // "BILL/2026/0001" o "Borrador"
  final String concepto; // "Intervención i12 · S00157"
  final String? ordenId; // "i12"
  final String fecha; // YYYY-MM-DD
  final double monto;
  final double pendiente;
  final String moneda;
  final String estado; // pendiente_validacion | por_pagar | pagado | cancelado

  const Pago({
    required this.id,
    required this.referencia,
    required this.concepto,
    required this.fecha,
    required this.monto,
    required this.pendiente,
    required this.moneda,
    required this.estado,
    this.ordenId,
  });

  factory Pago.fromJson(Map<String, dynamic> j) => Pago(
        id: _s(j['id']),
        referencia: _s(j['referencia']),
        concepto: _s(j['concepto']),
        ordenId: j['ordenId'] == null ? null : _s(j['ordenId']),
        fecha: _s(j['fecha']),
        monto: _d(j['monto']),
        pendiente: _d(j['pendiente']),
        moneda: _s(j['moneda']).isEmpty ? 'MXN' : _s(j['moneda']),
        estado: _s(j['estado']),
      );
}

class ResumenPagos {
  final List<Pago> pagos;
  final double pagado;
  final double porPagar;
  final double pendienteValidacion;
  final String moneda;

  const ResumenPagos({
    required this.pagos,
    required this.pagado,
    required this.porPagar,
    required this.pendienteValidacion,
    required this.moneda,
  });

  factory ResumenPagos.fromJson(Map<String, dynamic> j) {
    final t = (j['totales'] as Map<String, dynamic>?) ?? const {};
    return ResumenPagos(
      pagos: ((j['pagos'] as List?) ?? const []).map((e) => Pago.fromJson(e as Map<String, dynamic>)).toList(),
      pagado: _d(t['pagado']),
      porPagar: _d(t['porPagar']),
      pendienteValidacion: _d(t['pendienteValidacion']),
      moneda: _s(t['moneda']).isEmpty ? 'MXN' : _s(t['moneda']),
    );
  }
}

/// Etiquetas de estado de un pago (misma clave que el backend).
const estadosPago = <String, String>{
  'pendiente_validacion': 'En revisión',
  'por_pagar': 'Por pagar',
  'pagado': 'Pagado',
  'cancelado': 'Cancelado',
};

class ProductoCatalogo {
  final int id;
  final String codigo;
  final String nombre;
  final String descripcion;
  final double precio;
  final String categoria;
  final bool esServicio;

  const ProductoCatalogo({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.categoria,
    required this.esServicio,
  });

  factory ProductoCatalogo.fromJson(Map<String, dynamic> j) => ProductoCatalogo(
        id: (j['id'] as num?)?.toInt() ?? 0,
        codigo: _s(j['codigo']),
        nombre: _s(j['nombre']),
        descripcion: _s(j['descripcion']),
        precio: _d(j['precio']),
        categoria: _s(j['categoria']),
        esServicio: j['esServicio'] == true,
      );
}

class Cotizacion {
  final String id;
  final String referencia; // "S00158"
  final String cliente;
  final String fecha; // UTC de Odoo
  final double total;
  final String moneda;
  final String estado; // borrador | enviada | confirmada | cancelada
  final String? urlPortal;

  const Cotizacion({
    required this.id,
    required this.referencia,
    required this.cliente,
    required this.fecha,
    required this.total,
    required this.moneda,
    required this.estado,
    this.urlPortal,
  });

  factory Cotizacion.fromJson(Map<String, dynamic> j) => Cotizacion(
        id: _s(j['id']),
        referencia: _s(j['referencia']),
        cliente: _s(j['cliente']),
        fecha: _s(j['fecha']),
        total: _d(j['total']),
        moneda: _s(j['moneda']).isEmpty ? 'MXN' : _s(j['moneda']),
        estado: _s(j['estado']),
        urlPortal: j['urlPortal'] == null ? null : _s(j['urlPortal']),
      );
}

const estadosCotizacion = <String, String>{
  'borrador': 'Borrador',
  'enviada': 'Enviada',
  'confirmada': 'Confirmada',
  'cancelada': 'Cancelada',
};

/// Formato de dinero sin depender de intl: "$1,500.00".
String dinero(double v, [String moneda = 'MXN']) {
  final fixed = v.toStringAsFixed(2);
  final parts = fixed.split('.');
  final entero = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '\$$entero.${parts[1]}${moneda == 'MXN' ? '' : ' $moneda'}';
}
