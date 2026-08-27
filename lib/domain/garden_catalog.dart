import 'models/garden.dart';

/// The whole item catalogue. Art is a placeholder: every item is drawn as a
/// coloured rounded rect with its emoji and name, so adding one here is enough
/// to make it appear in the shop, the shelf and the garden.
class GardenCatalog {
  const GardenCatalog._();

  static const moss = GardenItemDef(
    id: 'plant_moss',
    name: '苔',
    category: GardenCategory.plant,
    emoji: '🌿',
    growable: true,
    costTokens: 30,
  );

  static const smallPlant = GardenItemDef(
    id: 'plant_small',
    name: '小さな植物',
    category: GardenCategory.plant,
    emoji: '🌱',
    growable: true,
    costTokens: 60,
  );

  static const fern = GardenItemDef(
    id: 'plant_fern',
    name: 'シダ',
    category: GardenCategory.plant,
    emoji: '🌾',
    growable: true,
    costTokens: 100,
  );

  static const sapling = GardenItemDef(
    id: 'plant_sapling',
    name: '若木',
    category: GardenCategory.plant,
    emoji: '🌳',
    width: 2,
    height: 2,
    growable: true,
    costTokens: 240,
  );

  static const pebble = GardenItemDef(
    id: 'deco_pebble',
    name: '小石',
    category: GardenCategory.deco,
    emoji: '🪨',
    costTokens: 20,
  );

  static const lamp = GardenItemDef(
    id: 'deco_lamp',
    name: '小さなランプ',
    category: GardenCategory.deco,
    emoji: '🏮',
    costTokens: 80,
  );

  static const signboard = GardenItemDef(
    id: 'deco_sign',
    name: '立て札',
    category: GardenCategory.deco,
    emoji: '🪧',
    costTokens: 40,
  );

  static const pond = GardenItemDef(
    id: 'deco_pond',
    name: '小さな池',
    category: GardenCategory.deco,
    emoji: '💧',
    width: 2,
    height: 2,
    costTokens: 180,
  );

  static const bench = GardenItemDef(
    id: 'furniture_bench',
    name: '木のベンチ',
    category: GardenCategory.furniture,
    emoji: '🪑',
    width: 2,
    costTokens: 140,
  );

  static const fence = GardenItemDef(
    id: 'furniture_fence',
    name: '白い柵',
    category: GardenCategory.furniture,
    emoji: '🚧',
    width: 2,
    costTokens: 70,
  );

  static const mailbox = GardenItemDef(
    id: 'furniture_mailbox',
    name: 'ポスト',
    category: GardenCategory.furniture,
    emoji: '📮',
    costTokens: 110,
  );

  static const all = <GardenItemDef>[
    moss,
    smallPlant,
    fern,
    sapling,
    pebble,
    lamp,
    signboard,
    pond,
    bench,
    fence,
    mailbox,
  ];

  static GardenItemDef? byId(String id) {
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Items sold at the seed shop, cheapest first.
  static List<GardenItemDef> get purchasable =>
      all.where((i) => i.purchasable).toList()
        ..sort((a, b) => a.costTokens!.compareTo(b.costTokens!));
}

/// Handed out once, on first launch, so the garden is never empty.
const initialGardenGrant = <String, int>{
  'plant_moss': 1,
  'deco_pebble': 2,
  'plant_small': 1,
};

/// The free plant starts on the ground rather than in the shelf.
const initialPlacedItemId = 'plant_small';
