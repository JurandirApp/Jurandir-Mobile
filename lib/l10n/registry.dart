// Lista de namespaces de tradução do app. Para uma área nova: crie
// `ns/<area>.dart` com um `I18nNamespace('<area>', ...)` e acrescente uma
// linha aqui (import + item da lista). Ver docs/app-i18n.md.

import 'i18n.dart';
import 'ns/buscar.dart';
import 'ns/cart.dart';
import 'ns/checkout.dart';
import 'ns/common.dart';
import 'ns/data.dart';
import 'ns/done.dart';
import 'ns/home.dart';
import 'ns/login.dart';
import 'ns/menu.dart';
import 'ns/onboarding.dart';
import 'ns/payments.dart';
import 'ns/pedidos.dart';
import 'ns/perfil.dart';
import 'ns/scanner.dart';
import 'ns/shell.dart';
import 'ns/splash.dart';
import 'ns/estab.dart';
import 'ns/estab_menu.dart';
import 'ns/estab_cfg.dart';
import 'ns/estab_ops.dart';
import 'ns/estab_stats.dart';
import 'ns/waiter.dart';
import 'ns/admin.dart';

/// Parte 1 (cliente) + comuns. Parte 2 (estab, waiter, admin): adicionar abaixo.
const List<I18nNamespace> appNamespaces = [
  commonStrings,
  shellStrings,
  splashStrings,
  onboardingStrings,
  homeStrings,
  buscarStrings,
  menuStrings,
  cartStrings,
  checkoutStrings,
  paymentsStrings,
  doneStrings,
  pedidosStrings,
  perfilStrings,
  scannerStrings,
  loginStrings,
  dataStrings,
  estabStrings,
  estabMenuStrings,
  estabCfgStrings,
  estabOpsStrings,
  estabStatsStrings,
  waiterStrings,
  adminStrings,
];
