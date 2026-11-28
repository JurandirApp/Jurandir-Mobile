import '../i18n.dart';

/// Textos de `pedidos` (ver docs/app-i18n.md).
const pedidosStrings = I18nNamespace(
  'pedidos',
  pt: {
    'title': 'Meus pedidos',
    'empty': 'Nenhum pedido ainda.',
    'scanAndOrder': 'Escanear e pedir',
    'resumePayment': 'Continuar pagamento',
    'deliveryCode': 'Seu código de entrega: {code}',
    'statusProducao': 'Em produção',
    'statusEntregue': 'Entregue',
    'statusAguardando': 'Aguardando pagamento',
    'resumeUnavailable': 'Não foi possível retomar este pedido. Faça o pedido de novo pelo cardápio.',
    'resumeOffline': 'Sem conexão pra retomar o pedido agora. Tente de novo.',
    'resumeMenuChanged': 'O cardápio mudou desde este pedido. Faça o pedido de novo pelo cardápio.',  },
  en: {
    'title': 'My orders',
    'empty': 'No orders yet.',
    'scanAndOrder': 'Scan and order',
    'resumePayment': 'Continue payment',
    'deliveryCode': 'Your delivery code: {code}',
    'statusProducao': 'In progress',
    'statusEntregue': 'Delivered',
    'statusAguardando': 'Awaiting payment',
    'resumeUnavailable': 'Couldn\'t resume this order. Place the order again from the menu.',
    'resumeOffline': 'No connection to resume the order right now. Try again.',
    'resumeMenuChanged': 'The menu changed since this order. Place the order again from the menu.',  },
  es: {
    'title': 'Mis pedidos',
    'empty': 'Todavía no hay pedidos.',
    'scanAndOrder': 'Escanear y pedir',
    'resumePayment': 'Continuar pago',
    'deliveryCode': 'Tu código de entrega: {code}',
    'statusProducao': 'En preparación',
    'statusEntregue': 'Entregado',
    'statusAguardando': 'Esperando el pago',
    'resumeUnavailable': 'No fue posible retomar este pedido. Haz el pedido de nuevo desde el menú.',
    'resumeOffline': 'Sin conexión para retomar el pedido ahora. Intenta de nuevo.',
    'resumeMenuChanged': 'El menú cambió desde este pedido. Haz el pedido de nuevo desde el menú.',  },
);
