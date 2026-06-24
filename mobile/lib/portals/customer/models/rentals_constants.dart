// Rentals & Event Equipment — marketplace vertical.

const rentalsEquipmentVertical = 'Rentals & Event Equipment';

const rentalEquipmentCategories = <String, String>{
  'chairs': 'Chairs',
  'tables': 'Tables',
  'canopies': 'Canopies',
  'tents': 'Tents',
  'stage-platforms': 'Stage Platforms',
  'led-screens': 'LED Screens',
  'sound-systems': 'Sound Systems',
  'lighting-systems': 'Lighting Systems',
  'generators': 'Generators',
  'mobile-toilets': 'Mobile Toilets',
  'cooling-fans': 'Cooling Fans',
  'air-conditioners': 'Air Conditioners',
  'dance-floors': 'Dance Floors',
  'cutlery-crockery': 'Cutlery & Crockery',
  'thrones-vip-seating': 'Thrones & VIP Seating',
  'backdrops': 'Backdrops',
  'photo-booths': 'Photo Booths',
  'event-equipment': 'Event Equipment',
};

const rentalCategorySlugs = rentalEquipmentCategories.keys.toList();

String rentalCategoryLabel(String slug) => rentalEquipmentCategories[slug] ?? slug;

bool isRentalEquipmentCategory(String label) {
  final lower = label.toLowerCase();
  if (lower == rentalsEquipmentVertical.toLowerCase()) return true;
  return rentalEquipmentCategories.values.any((v) => v.toLowerCase() == lower);
}

String? rentalSubcategoryFromSlug(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('chair')) return 'Chairs';
  if (lower.contains('table')) return 'Tables';
  if (lower.contains('canop')) return 'Canopies';
  if (lower.contains('tent')) return 'Tents';
  if (lower.contains('stage')) return 'Stage Platforms';
  if (lower.contains('led') || lower.contains('screen')) return 'LED Screens';
  if (lower.contains('sound') || lower.contains('speaker') || lower.contains('pa-')) return 'Sound Systems';
  if (lower.contains('light')) return 'Lighting Systems';
  if (lower.contains('generator') || lower.contains('gen-set')) return 'Generators';
  if (lower.contains('toilet') || lower.contains('mobile-wc')) return 'Mobile Toilets';
  if (lower.contains('fan')) return 'Cooling Fans';
  if (lower.contains('ac') || lower.contains('air-condition')) return 'Air Conditioners';
  if (lower.contains('dance')) return 'Dance Floors';
  if (lower.contains('cutlery') || lower.contains('crockery')) return 'Cutlery & Crockery';
  if (lower.contains('throne') || lower.contains('vip-seat')) return 'Thrones & VIP Seating';
  if (lower.contains('backdrop')) return 'Backdrops';
  if (lower.contains('photo-booth') || lower.contains('photobooth')) return 'Photo Booths';
  if (lower.contains('rental') || lower.contains('equipment')) return rentalsEquipmentVertical;
  return null;
}
