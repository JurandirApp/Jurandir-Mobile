# Deploy no Google Play — teste do PagBank (Google Pay em sandbox)

Objetivo: gerar um `.aab` que **habilita o Google Pay via PagBank** e subir na faixa
**Internal testing** do Play pra testar sem afetar a produção. O que muda em relação
à build de produção é **um define**: `PAGBANK_MERCHANT_ID` (o `ACCO_` da conta PagBank).

> **Crédito NÃO precisa deste build.** O cartão usa a chave pública que o backend
> devolve conforme o toggle (`/api/public/pagbank/public-key`), então crédito já dá
> pra testar na build que está no Play, só com a config de backend (ver no fim).
> Este build é pro **Google Pay**, que lê o `PAGBANK_MERCHANT_ID` em tempo de build.

---

## 0. Pré-requisitos (uma vez)

- `android/key.properties` + o `.jks` de upload presentes na máquina (são gitignored;
  é o mesmo keystore que assinou a 1.0.8 que já está no Play). Sem eles o `.aab` sai
  assinado em debug e o Play recusa.
- Flutter no PATH (`flutter --version`).
- App no Play Console: **`br.app.jurandirgarcomdigital`** (conta de organização).
- `PAGBANK_MERCHANT_ID` confirmado: hoje está o `ACCO_` **da plataforma (sandbox)**
  em [dart_defines.pagbank-test.json](dart_defines.pagbank-test.json). Se o Google Pay
  der erro de merchant, confirmar com o PagBank qual id vai no `gatewayMerchantId`.

## 1. Gerar o `.aab` (PowerShell)

```powershell
cd "d:\Projetos 2.0\Jurandir\jurandir-app"
flutter pub get
flutter build appbundle --release `
  --build-number=11 `
  --dart-define-from-file=dart_defines.pagbank-test.json
```

- `--build-number=11`: o Play exige `versionCode` **maior** que o já publicado (hoje 10).
  A cada novo envio, suba esse número (12, 13, …). O `versionName` segue `1.0.8`.
- Saída: `build\app\outputs\bundle\release\app-release.aab`.
- Se falhar por falta de espaço (C: cheio), aponte o cache do Gradle pro D: antes do
  build: `$env:GRADLE_USER_HOME = "d:\gradle-cache"`.

## 2. Subir no Play (Internal testing)

1. Play Console → app **Jurandir (br.app.jurandirgarcomdigital)** → **Testing → Internal testing**.
2. **Create new release** → envie o `app-release.aab`.
3. Em **Testers**, garanta que seu e-mail/conta do celular está na lista.
4. **Review release → Start rollout to Internal testing**.
5. Copie o **link de opt-in** da faixa, abra no celular, aceite virar testador e instale
   o app por ele (vem com o Google Pay já no PagBank).

> Por que Internal testing e não produção: este build é `PAY_ENV=TEST` (Google Pay de
> teste) + backend em modo Teste. Não deve ir pros usuários reais da faixa de produção.

## 3. Testar no celular (Android real, com Google Play Services)

**Antes, no backend/admin:**
- Vercel: `PAGBANK_TOKEN_TEST` presente + **Redeploy**.
- Admin → aba **Pagamentos** → **PagBank = Teste**.
- Admin → roteamento do bar de teste → **crédito → PagBank** e **Google Pay → PagBank**.

**No app:**
- **Crédito**: finalize um pedido com o cartão de teste **Visa 4539620659922097**,
  CVV **123**, validade **12/2026** → deve concluir como **pago (PAID)**.
- **Google Pay**: escolha Google Pay no checkout. A folha do Google abre em ambiente de
  teste. ⚠️ **Honestidade**: em `PAY_ENV=TEST` o Google devolve um **token de teste** —
  isso valida o **fluxo** (folha abre, token chega no backend, roteia pro PagBank), mas
  a confirmação "PAID de verdade" do Google Pay só fecha em **produção** (device real +
  `ACCO_` de produção + pós-homologação + allowlist do Google).

---

## Quando for pra PRODUÇÃO (lançamento real, depois de homologar)

Não use este arquivo. No [dart_defines.prod.json](dart_defines.prod.json), adicione:
- `PAGBANK_MERCHANT_ID` = o `ACCO_` **de produção** da plataforma;
- `GOOGLE_MERCHANT_ID` = o merchant id do **Google Pay Business Console** (obrigatório
  em produção);
- mantenha `PAY_ENV=PRODUCTION`.

Buildar com `--dart-define-from-file=dart_defines.prod.json` e subir na faixa de
**produção**. Lembrando: cobrança real no PagBank só depois da homologação (allowlist).
