import 'package:flutter/material.dart';

/// Tokens de cor da marca Jurandir — extraídos 1:1 do design (`design/`).
///
/// Duas bases de creme intencionais: [dune] (marca/texto sobre escuro) e
/// [canvas] (fundo das telas). Não colapsar as duas.
abstract final class AppColors {
  // Base / marca
  static const Color dune = Color(0xFFEDD8A3); // areia (marca; texto/ícone sobre escuro)
  static const Color canvas = Color(0xFFF8EFDA); // fundo da tela (creme claro)
  static const Color ink = Color(0xFF141821); // tinta (texto, bordas, headers escuros, nav)
  static const Color inkHover = Color(0xFF734319); // coconut-600

  // Acentos
  static const Color coral = Color(0xFFFF6B4A); // CTA primário, FAB, add
  static const Color coralDeep = Color(0xFFEF5130); // preços, eyebrows, "ver todos"
  static const Color amber = Color(0xFFFFC24B); // sun-400: avatar, estrelas, badges rank

  // Teal / ocean
  static const Color ocean = Color(0xFF0F7E84);
  static const Color oceanDeep = Color(0xFF0C6A70); // links
  static const Color oceanDark = Color(0xFF0C4347);
  static const Color teal = Color(0xFF14B8A6);

  // Semânticas
  static const Color success = Color(0xFF10B981);
  static const Color successText = Color(0xFF047857);
  static const Color successBg = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningText = Color(0xFFB45309);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFE11D48);
  static const Color dangerText = Color(0xFFBE123C);
  static const Color dangerBg = Color(0xFFFFE4E6);
  static const Color rose = Color(0xFFFB7185);

  // Métodos de pagamento
  static const Color credit = Color(0xFF3B82F6);
  static const Color debit = Color(0xFF10B981);
  static const Color pix = Color(0xFF14B8A6);
  static const Color usdc = Color(0xFF8B5CF6);

  // Paleta de gráficos (categorias / donuts)
  static const List<Color> chart = [
    Color(0xFFFF6B4A),
    Color(0xFF0F7E84),
    Color(0xFFFFC24B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF94A3B8),
  ];

  /// Tinta com opacidade — texto/bordas/fills sobre fundo claro.
  static Color inkA(double opacity) => ink.withValues(alpha: opacity);

  /// Areia com opacidade — texto/bordas/fills sobre fundo escuro.
  static Color duneA(double opacity) => dune.withValues(alpha: opacity);
}
