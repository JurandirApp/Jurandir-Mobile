# App Flutter — plano de tradução (i18n)

Situação em 2026-11-27 (branch `feat/backlog-lote2`).

## O que existe hoje

- **Nenhuma infraestrutura de i18n.** Não há `flutter_localizations` nem `intl`
  no `pubspec.yaml`, nem `l10n.yaml`, arquivos `.arb` ou `AppLocalizations`.
- Todos os textos estão escritos direto no código, em português.
- Formatação de dinheiro/número é manual e fixa em pt-BR
  (`lib/core/utils/money.dart`: `R$ 22,00`, milhar com ponto) — há cópias locais
  em `estab_mesa_screen.dart` e `estab_rastreio_screen.dart`.
- Widgets Material (seletor de hora, botões OK/Cancel etc.) aparecem no padrão
  do Flutter (inglês), porque sem `flutter_localizations` só existe en_US.
- Único uso de locale: `checkout_screen.dart` manda
  `platformDispatcher.locale.toLanguageTag()` como `languageTag` do navegador
  no 3DS da Tuna (não é texto de tela).

## O que este lote entregou

- Preferência **Idioma (Português / English)** no Perfil do cliente (logado ou
  não) e na Conta do estabelecimento — `lib/core/widgets/language_selector.dart`.
- Guardada no aparelho (`SharedPreferences`, chave `app_language`), exposta pelo
  `appLanguageProvider` (`lib/core/data/app_language.dart`) e ligada em
  `MaterialApp.locale` (`lib/app.dart`).
- **Nada foi traduzido ainda.** Ao escolher English o app mostra um aviso de que
  a tradução está chegando. Sem `flutter_localizations`, o `locale` não muda
  nada visível (o Flutter resolve pra en_US, como já era).

## Tamanho do trabalho (contagem aproximada)

Heurística: literais de string com cara de texto visível (começa com maiúscula,
tem espaço ou acento), ignorando imports, chaves JSON, rotas e URLs.
Script: `build/tmp_scripts/count_strings.py` (não versionado; recriar se
precisar). Números servem pra dimensionar, não são exatos.

| Pasta | Arquivos | Ocorrências | Textos únicos |
|---|---:|---:|---:|
| `features/estab/presentation` | 16 | 326 | 255 |
| `features/checkout/presentation` | 7 | 179 | 156 |
| `features/admin/presentation` | 10 | 155 | 123 |
| `features/waiter/presentation` | 2 | 34 | 32 |
| `core/payments` (mensagens de erro) | 7 | 23 | 22 |
| `features/home/presentation` | 1 | 20 | 20 |
| `features/perfil/presentation` | 1 | 19 | 18 |
| `features/onboarding/presentation` | 2 | 18 | 18 |
| `features/menu/presentation` | 2 | 17 | 15 |
| `features/buscar/presentation` | 1 | 11 | 9 |
| `features/pedidos/presentation` | 1 | 11 | 11 |
| `features/login/presentation` | 1 | 10 | 9 |
| `features/scanner/presentation` | 1 | 10 | 9 |
| `features/done/presentation` | 1 | 7 | 7 |
| `features/shell/*` (abas) | 3 | 13 | 13 |
| `features/cart`, `pedidos/resume_order.dart` | 2 | 8 | 8 |
| `core/data/models.dart`, `kitchen.dart`, outros `core/*` | ~8 | ~20 | ~18 |
| **Total de UI** | **~66** | **~880** | **~745** |

Fora da conta acima: `core/data/seed_data.dart` (149 ocorrências, dados de
demonstração — não traduzir) e os `'Bearer $token'` de `public_api.dart`.

Também há texto que **vem do servidor** e não é do app: nomes/descrições do
cardápio, categorias, `kitchenNextOpenLabel`, mensagens de recusa dos gateways
(`detail`). Esses precisam de decisão à parte (servidor mandar no idioma pedido,
via `Accept-Language`, ou ficar em português).

## Proposta de execução

1. **Infra (0,5 dia).** Adicionar `flutter_localizations` (vem do SDK, sem
   download) + `intl` (pub), `generate: true` e `l10n.yaml`; `app_pt.arb` como
   modelo e `app_en.arb`. Ligar `localizationsDelegates`/`supportedLocales` no
   `MaterialApp` (o `appLanguageProvider` já entrega o `locale`). Trocar
   `money()`/datas por `NumberFormat`/`DateFormat` com locale (BRL continua
   moeda; muda só a pontuação).
2. **Telas do cliente primeiro (2–3 dias, ~300 textos).** home, buscar, menu,
   item sheet, checkout + folhas de cartão/Pix/3DS, pedidos, done, perfil,
   onboarding, scanner, login. É o que um turista vê.
3. **Garçom + estabelecimento (2–3 dias, ~290 textos).** `estab/*`, `waiter/*`.
4. **Admin (1 dia, ~125 textos)** — uso interno; pode ficar por último ou só em pt.
5. **Revisão de tradução + QA visual (1–2 dias).** Inglês costuma ser mais
   curto, mas checar botões/labels que quebram linha; plurais (`1 entregue` /
   `2 entregues`) devem ir pra ICU plural no ARB.

**Estimativa total: ~7–10 dias de dev** para cliente + estabelecimento + garçom
em inglês, mais o que o servidor precisar (passo à parte).

## Cuidados

- Strings com interpolação (`'Pagar ${money(grand)}'`) viram placeholders no ARB.
- Textos montados por concatenação (ex.: `statusLabel` de `ClientOrderItem`)
  precisam ser reescritos com plural/ICU, não só traduzidos.
- Testes que procuram texto (`find.text('SEU GARÇOM DIGITAL')`) passam a
  depender do locale do teste — fixar `locale: Locale('pt','BR')` neles.
- Manter o português como padrão e fallback.
