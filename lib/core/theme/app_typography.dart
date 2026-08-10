import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tipografia do app.
///
/// Bricolage Grotesque (display) = títulos, eyebrows, números/stats — quase
/// sempre `w800`, MAIÚSCULO, letter-spacing negativo. Aplique `.toUpperCase()`
/// no texto ao usar os estilos de título.
/// Hanken Grotesk (corpo) = descrições, labels, botões, preços.
abstract final class AppText {
  // ---- Display (Bricolage Grotesque) ----
  static TextStyle display({
    double size = 16,
    FontWeight weight = FontWeight.w800,
    double letterSpacing = -0.3,
    double? height,
    Color color = AppColors.ink,
  }) => TextStyle(
    fontFamily: 'Bricolage Grotesque',
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
    color: color,
  );

  // ---- Corpo (Hanken Grotesk) ----
  static TextStyle body({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    double letterSpacing = 0,
    double? height,
    Color color = AppColors.ink,
  }) => TextStyle(
    fontFamily: 'Hanken Grotesk',
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
    color: color,
  );

  // ---- Estilos nomeados (do design) ----
  static TextStyle get splashTag =>
      display(size: 12, letterSpacing: 2.8, color: AppColors.dune);

  static TextStyle get onboardTitle =>
      display(size: 30, letterSpacing: -0.6, height: 0.95, color: AppColors.dune);

  /// Título de página (H1).
  static TextStyle get pageTitle => display(size: 24, letterSpacing: -0.5);

  /// H2 de seção (uppercase, apagado).
  static TextStyle get sectionTitle =>
      display(size: 14, letterSpacing: 0.2, color: AppColors.inkA(0.6));

  /// H2 grande da home.
  static TextStyle get homeTitle => display(size: 17, letterSpacing: -0.2);

  /// Valor de stat (números grandes).
  static TextStyle get stat => display(size: 20, height: 1);

  /// Eyebrow (rótulo coral acima de títulos).
  static TextStyle get eyebrow =>
      body(size: 11, weight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.coralDeep);

  static TextStyle get itemName => body(size: 15, weight: FontWeight.w700);

  static TextStyle get meta => body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.6));

  static TextStyle get price => body(size: 15, weight: FontWeight.w800, color: AppColors.coralDeep);

  static TextStyle get button => body(size: 15, weight: FontWeight.w700);

  static TextStyle get pill => body(size: 13, weight: FontWeight.w700);
}
