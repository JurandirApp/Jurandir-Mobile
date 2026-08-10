import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_backlog_screen.dart';
import '../../features/admin/presentation/admin_buscas_screen.dart';
import '../../features/admin/presentation/admin_cadastros_screen.dart';
import '../../features/admin/presentation/admin_conta_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_faturamento_screen.dart';
import '../../features/admin/presentation/admin_taxas_screen.dart';
import '../../features/buscar/presentation/buscar_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/done/presentation/done_screen.dart';
import '../../features/estab/presentation/estab_auditoria_screen.dart';
import '../../features/estab/presentation/estab_cardapio_screen.dart';
import '../../features/estab/presentation/estab_config_screen.dart';
import '../../features/estab/presentation/estab_conta_screen.dart';
import '../../features/estab/presentation/estab_kpis_screen.dart';
import '../../features/estab/presentation/estab_pedidos_screen.dart';
import '../../features/estab/presentation/estab_perfil_screen.dart';
import '../../features/estab/presentation/estab_qr_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/login/presentation/login_screen.dart';
import '../../features/menu/presentation/menu_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/pedidos/presentation/pedidos_screen.dart';
import '../../features/perfil/presentation/perfil_screen.dart';
import '../../features/scanner/presentation/scanner_screen.dart';
import '../../features/shell/admin_scaffold.dart';
import '../../features/shell/client_scaffold.dart';
import '../../features/shell/estab_scaffold.dart';
import '../../features/splash/presentation/splash_screen.dart';

/// Rotas do app:
/// - Splash / Onboarding: tela cheia.
/// - Shell do cliente (bottom nav): /home, /buscar, /pedidos, /perfil.
/// - Tela cheia: /menu, /checkout, /done, /scanner, /login.
///
/// TODO(migração): shells de Estabelecimento e Admin.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ClientScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/buscar', builder: (context, state) => const BuscarScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/pedidos', builder: (context, state) => const PedidosScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/perfil', builder: (context, state) => const PerfilScreen()),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            EstabScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/estab/pedidos', builder: (context, state) => const EstabPedidosScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/estab/cardapio', builder: (context, state) => const EstabCardapioScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/estab/qr', builder: (context, state) => const EstabQrScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/estab/kpis', builder: (context, state) => const EstabKpisScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/estab/conta',
              builder: (context, state) => const EstabContaScreen(),
              routes: [
                GoRoute(path: 'auditoria', builder: (context, state) => const EstabAuditoriaScreen()),
                GoRoute(path: 'perfil', builder: (context, state) => const EstabPerfilScreen()),
                GoRoute(path: 'config', builder: (context, state) => const EstabConfigScreen()),
              ],
            ),
          ]),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdminScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/admin/dashboard', builder: (context, state) => const AdminDashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/admin/faturamento', builder: (context, state) => const AdminFaturamentoScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/admin/buscas', builder: (context, state) => const AdminBuscasScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/admin/backlog', builder: (context, state) => const AdminBacklogScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/conta',
              builder: (context, state) => const AdminContaScreen(),
              routes: [
                GoRoute(path: 'cadastros', builder: (context, state) => const AdminCadastrosScreen()),
                GoRoute(path: 'taxas', builder: (context, state) => const AdminTaxasScreen()),
              ],
            ),
          ]),
        ],
      ),
      GoRoute(path: '/menu', builder: (context, state) => const MenuScreen()),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(path: '/done', builder: (context, state) => const DoneScreen()),
      GoRoute(path: '/scanner', builder: (context, state) => const ScannerScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    ],
  );
});
