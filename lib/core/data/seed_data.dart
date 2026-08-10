import 'models.dart';

/// Slug do estabelecimento demo (usado p/ buscar o cardápio real na API).
const kDemoSlug = 'quiosque-do-mar';

/// Dados de demonstração do design (mesmo seed do protótipo `.dc.html`).
///
/// TODO(api): substituir pelas chamadas à API pública quando ligarmos os dados
/// reais. Mantido fiel ao design para a fase de migração visual.

const kEstablishments = <Establishment>[
  Establishment(id: 'e3', name: 'Sunset Beach Club', location: 'Centro, Balneário Camboriú', cuisine: 'Petiscaria', orders: 689, rating: 4.4, open: true),
  Establishment(id: 'e8', name: 'Brava Norte Beach Bar', location: 'Praia Brava Norte, Itajaí', cuisine: 'Hamburgueria', orders: 530, rating: 4.7, open: true),
  Establishment(id: 'e10', name: 'Sul do Mar Petiscaria', location: 'Praia Brava Sul, Itajaí', cuisine: 'Petiscaria', orders: 480, rating: 4.5, open: true),
  Establishment(id: 'e2', name: 'Bar do Zé', location: 'Jurerê, Florianópolis', cuisine: 'Boteco', orders: 412, rating: 4.5, open: false),
  Establishment(id: 'e13', name: 'Bar do Japa', location: 'Centro, Londrina', cuisine: 'Japonesa', orders: 380, rating: 4.6, open: true),
  Establishment(id: 'e9', name: 'Norte Drinks & Cia', location: 'Praia Brava Norte, Itajaí', cuisine: 'Drinks & Coquetéis', orders: 210, rating: 4.1, open: true),
  Establishment(id: 'e11', name: 'Bar do Sul Brava', location: 'Praia Brava Sul, Itajaí', cuisine: 'Boteco', orders: 165, rating: 4.2, open: false),
  Establishment(id: 'e4', name: 'Cabana da Lia', location: 'Bombas, Bombinhas', cuisine: 'Frutos do mar', orders: 158, rating: 4.6, open: true),
  Establishment(id: 'live', name: 'Quiosque do Mar', location: 'Praia Brava, Itajaí', cuisine: 'Frutos do mar', orders: 8, rating: 4.8, open: true),
];

const kMenu = <MenuItem>[
  MenuItem(id: 1, name: 'Caipirinha de Limão', desc: 'Cachaça artesanal, limão tahiti e gelo', price: 22, oldPrice: 28, photoId: 'photo-1551538827-9c037cb4f32a', category: 'Drinks'),
  MenuItem(id: 2, name: 'Aperol Spritz', desc: 'Aperol, prosecco e laranja', price: 28, oldPrice: 34, photoId: 'photo-1560512823-829485b8bf24', category: 'Drinks'),
  MenuItem(id: 3, name: 'Heineken Long Neck', desc: 'Pilsen bem gelada', price: 12, photoId: 'photo-1608270586620-248524c67de9', category: 'Cervejas'),
  MenuItem(id: 4, name: 'Stella Artois 600ml', desc: 'Garrafa compartilhável', price: 18, photoId: 'photo-1535958636474-b021ee887b13', category: 'Cervejas'),
  MenuItem(id: 5, name: 'Água de Coco', desc: 'Coco verde na hora', price: 10, photoId: 'photo-1520950237264-3e10a6d27dd5', category: 'Bebidas'),
  MenuItem(id: 6, name: 'Coca-Cola Lata', desc: 'Gelada, 350ml', price: 8, photoId: 'photo-1554866585-cd94860890b7', category: 'Bebidas'),
  MenuItem(id: 7, name: 'Porção de Camarão', desc: 'Empanado com molho tártaro', price: 68, oldPrice: 89, photoId: 'photo-1625938145312-c971e35e51f3', category: 'Porções'),
  MenuItem(id: 8, name: 'Batata Frita', desc: 'Rústica com cheddar e bacon', price: 38, photoId: 'photo-1573080496219-bb080dd4f877', category: 'Porções'),
  MenuItem(id: 9, name: 'Bowl de Açaí', desc: 'Granola, banana e mel', price: 28, oldPrice: 36, photoId: 'photo-1590301157890-4810ed352733', category: 'Saudáveis'),
  MenuItem(id: 10, name: 'Petit Gâteau', desc: 'Chocolate com sorvete', price: 32, oldPrice: 38, photoId: 'photo-1606313564200-e75d5e30476c', category: 'Sobremesas'),
  MenuItem(id: 11, name: 'Churros', desc: 'Com doce de leite', price: 24, photoId: 'photo-1612203985729-70726954388c', category: 'Sobremesas'),
];

/// Mesas/guarda-sóis (QR) do estabelecimento demo.
const kQrSpots = <String>['Guarda-sol nº 14', 'Guarda-sol nº 22', 'Deck 03'];

/// Pedidos do painel do estabelecimento (demo).
const kEstabOrders = <EstabOrder>[
  EstabOrder(id: 43, status: 'aguardando', loc: 'Guarda-sol nº 07', customer: 'Turma da Júlia', minutesAgo: 2, items: [(1, 'Aperol Spritz', 28), (1, 'Batata Frita', 38), (2, 'Heineken Long Neck', 12)], split: (3, 1)),
  EstabOrder(id: 42, status: 'producao', loc: 'Guarda-sol nº 22', customer: 'Marina', minutesAgo: 6, method: 'pix', note: 'Caipirinha sem açúcar, por favor.', items: [(1, 'Caipirinha de Limão', 22), (1, 'Porção de Camarão', 68)]),
  EstabOrder(id: 41, status: 'producao', loc: 'Guarda-sol nº 14', minutesAgo: 19, method: 'credito', items: [(2, 'Água de Coco', 10), (1, 'Bowl de Açaí', 28)]),
  EstabOrder(id: 40, status: 'entregue', loc: 'Deck 03', minutesAgo: 74, method: 'debito', items: [(1, 'Batata Frita', 38), (2, 'Heineken Long Neck', 12)]),
  EstabOrder(id: 39, status: 'entregue', loc: 'Guarda-sol nº 07', minutesAgo: 150, method: 'usdc', items: [(1, 'Aperol Spritz', 28), (1, 'Petit Gâteau', 32)]),
];

/// Tipo por estabelecimento (Admin).
const kEstabType = {
  'e3': 'Balada', 'e8': 'Estab. de Praia', 'e10': 'Restaurante', 'e2': 'Bar',
  'e13': 'Bar', 'e9': 'Quiosque', 'e11': 'Bar', 'e4': 'Quiosque', 'live': 'Quiosque',
};

/// Fee (% do Jurandir) por estabelecimento; default 8%.
const _estabFee = {'e2': 7.0, 'e3': 9.0, 'e10': 9.0, 'e11': 7.0, 'live': 8.0};

double estabFee(String id) => _estabFee[id] ?? 8.0;

/// Backlog de compras da plataforma (Admin).
const kBacklog = <BacklogPurchase>[
  BacklogPurchase(code: 'PED-7F3A9C2D', estab: 'Quiosque do Mar', city: 'Itajaí/SC', minutesAgo: 3, method: 'pix', card: '', total: 109, items: '1× Combo Casal, 1× Água de Coco'),
  BacklogPurchase(code: 'PED-4C8A21EF', estab: 'Bar do Japa', city: 'Londrina/PR', minutesAgo: 12, method: 'credito', card: 'Visa •••• 4412', total: 96, items: '2× Lámen do Japa'),
  BacklogPurchase(code: 'PED-1D5B90A3', estab: 'Sunset Beach Club', city: 'Balneário Camboriú/SC', minutesAgo: 26, method: 'split', card: '', total: 90, items: '1× Aperol Spritz, 1× Batata Frita, 2× Long Neck'),
  BacklogPurchase(code: 'PED-9C04D7B1', estab: 'Brava Norte Beach Bar', city: 'Itajaí/SC', minutesAgo: 41, method: 'debito', card: 'Elo •••• 2210', total: 74, items: '1× Burger Brava, 1× Heineken Long Neck'),
  BacklogPurchase(code: 'PED-B37F10C6', estab: 'Estúdio da Bruxa', city: 'Londrina/PR', minutesAgo: 65, method: 'usdc', card: '', total: 62.7, items: '1× Burrito de Carnitas, 1× Chamoyada'),
  BacklogPurchase(code: 'PED-64A0C9E7', estab: 'Sul do Mar Petiscaria', city: 'Itajaí/SC', minutesAgo: 90, method: 'pix', card: '', total: 129, items: '1× Moqueca de Peixe, 2× Suco de Laranja'),
  BacklogPurchase(code: 'PED-F92B37D4', estab: 'Bar do Zé', city: 'Florianópolis/SC', minutesAgo: 130, method: 'credito', card: 'Master •••• 7810', total: 84, items: '2× Petisco do Zé, 2× Brahma 600ml'),
  BacklogPurchase(code: 'PED-80D6E4A5', estab: 'Cabana da Lia', city: 'Bombinhas/SC', minutesAgo: 210, method: 'pix', card: '', total: 56, items: '2× Água de Coco, 1× Porção de Camarão'),
];

/// Dimensões de busca (Admin) → lista de (rótulo, contagem).
const kBuscaDims = {
  'city': [('Itajaí/SC', 42), ('Balneário Camboriú/SC', 28), ('Florianópolis/SC', 19), ('Londrina/PR', 16), ('Itapema/SC', 12), ('Bombinhas/SC', 9)],
  'bairro': [('Praia Brava', 24), ('Centro', 18), ('Praia Brava Norte', 14), ('Jurerê', 11), ('Praia Brava Sul', 10), ('Meia Praia', 7)],
  'culinaria': [('Frutos do mar', 33), ('Mexicana/Latina', 26), ('Petiscaria', 21), ('Boteco', 15), ('Drinks & Coquetéis', 12), ('Hamburgueria', 9)],
  'tipo': [('Bar', 31), ('Quiosque', 22), ('Restaurante', 18), ('Estab. de Praia', 10), ('Balada', 6)],
};
