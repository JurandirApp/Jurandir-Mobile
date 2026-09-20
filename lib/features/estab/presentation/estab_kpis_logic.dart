import '../../../core/data/models.dart';

/// Resultado dos KPIs do estabelecimento (só cálculo, sem UI).
class EstabKpis {
  final double faturamento;
  final int pedidos;
  final double ticket;
  final int emProducao;

  /// Categoria → valor vendido, já ordenado do maior pro menor.
  final List<MapEntry<String, double>> byCat;

  /// Método de pagamento → valor.
  final Map<String, double> byPay;

  /// Top 3 itens por quantidade vendida.
  final List<MapEntry<String, int>> topSellers;

  const EstabKpis({
    required this.faturamento,
    required this.pedidos,
    required this.ticket,
    required this.emProducao,
    required this.byCat,
    required this.byPay,
    required this.topSellers,
  });
}

/// Calcula os KPIs do painel do estabelecimento.
///
/// Regra central (o bug que isto corrige): **só pedido PAGO conta como venda.**
/// Pago = status `producao` ou `entregue`. `aguardando` (não pago / Pix
/// expirado) NÃO entra em faturamento/pedidos/ticket/categoria/método — igual
/// à web. "Em produção" é uma contagem ao vivo (todos em `producao`).
EstabKpis computeEstabKpis({
  required List<PanelOrder> all,
  required List<PanelMenuItem> menu,
  required int cutoffMs,
}) {
  final orders =
      all.where((o) => o.ts >= cutoffMs && o.status != 'aguardando').toList();

  final faturamento = orders.fold(0.0, (s, o) => s + o.total);
  final pedidos = orders.length;
  final ticket = pedidos == 0 ? 0.0 : faturamento / pedidos;
  final emProducao = all.where((o) => o.status == 'producao').length;

  // Vendas por categoria (mapeia nome do item → categoria pelo cardápio).
  final catOf = {for (final m in menu) m.name: m.cat};
  final byCat = <String, double>{};
  for (final o in orders) {
    for (final it in o.items) {
      var c = catOf[it.name] ?? 'Outros';
      if (c.isEmpty) c = 'Outros';
      byCat[c] = (byCat[c] ?? 0) + it.qty * it.price;
    }
  }
  final sortedCats = byCat.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  // Vendas por método.
  final byPay = <String, double>{};
  for (final o in orders) {
    byPay[o.pay] = (byPay[o.pay] ?? 0) + o.total;
  }

  // Mais vendidos (por quantidade).
  final byItem = <String, int>{};
  for (final o in orders) {
    for (final it in o.items) {
      byItem[it.name] = (byItem[it.name] ?? 0) + it.qty;
    }
  }
  final topSellers = (byItem.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
      .take(3)
      .toList();

  return EstabKpis(
    faturamento: faturamento,
    pedidos: pedidos,
    ticket: ticket,
    emProducao: emProducao,
    byCat: sortedCats,
    byPay: byPay,
    topSellers: topSellers,
  );
}
