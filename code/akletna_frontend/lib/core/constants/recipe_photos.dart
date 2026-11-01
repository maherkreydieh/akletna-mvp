/// Photos bundled with the app for recipes that have no image link.
/// Keyed by lower-case recipe name. Sources and licences:
/// docs/IMAGE_CREDITS.md.
const Map<String, String> _bundledRecipePhotos = {
  'hummus bi tahini': 'hummus_bi_tahini.png',
  'tabbouleh': 'tabbouleh.webp',
  'fattoush': 'fattoush.webp',
  'mdardara': 'mujaddara.jpg',
  'shorbet adas': 'shorbet_adas.jpg',
  'batata harra': 'batata_harra.webp',
  'loubieh bi zeit': 'loubieh_bi_zeit.png',
  'lebanese rice with vermicelli': 'vermicelli_rice.jpg',
  'kafta bil sanieh': 'kafta.webp',
  'shish tawook': 'shish_tawook.webp',
  'moutabbal': 'moutabbal.jpg',
  'labneh with olive oil': 'labneh.png',
  'egyptian koshary': 'koshary.jpg',
};

/// Returns the bundled photo asset for [recipeName], or null if there is none.
String? bundledRecipePhoto(String? recipeName) {
  final file = recipeName == null
      ? null
      : _bundledRecipePhotos[recipeName.trim().toLowerCase()];
  return file == null ? null : 'assets/images/recipes/$file';
}
