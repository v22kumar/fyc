/// A single Thirukkural couplet with Tamil and English text and meanings.
class ThirukkuralModel {
  final int number;
  final String line1;
  final String line2;
  final String tamilMeaning;
  final String englishCouplet;
  final String englishMeaning;
  final int adhikaram;
  final String paalTa;
  final String paalEn;

  const ThirukkuralModel({
    required this.number,
    required this.line1,
    required this.line2,
    required this.tamilMeaning,
    required this.englishCouplet,
    required this.englishMeaning,
    required this.adhikaram,
    required this.paalTa,
    required this.paalEn,
  });

  factory ThirukkuralModel.fromJson(Map<String, dynamic> json) {
    return ThirukkuralModel(
      number: json['number'] as int,
      line1: (json['line1'] as String?) ?? '',
      line2: (json['line2'] as String?) ?? '',
      tamilMeaning: (json['tamil_meaning'] as String?) ?? '',
      englishCouplet: (json['english_couplet'] as String?) ?? '',
      englishMeaning: (json['english_meaning'] as String?) ?? '',
      adhikaram: (json['adhikaram'] as int?) ?? 0,
      paalTa: (json['paal_ta'] as String?) ?? '',
      paalEn: (json['paal_en'] as String?) ?? '',
    );
  }
}
