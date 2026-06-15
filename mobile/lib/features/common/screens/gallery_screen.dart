import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/storage/local_storage.dart';
import '../../../service_locator.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String get _lang => sl<LocalStorage>().getLang();

  final List<Map<String, String>> _photos = [
    {
      'title_en': 'Green FYC Tree Planting',
      'title_ta': 'பசுமை பிரண்ட்ஸ் மரக்கன்று நடுதல்',
      'desc_en': 'Successfully planted 150+ native saplings in Nagercoil Town limits.',
      'desc_ta': 'நாகர்கோவில் நகர எல்லைக்குள் வெற்றிகரமாக 150+ நாட்டு மரக்கன்றுகள் நடப்பட்டன.',
      'category_en': 'Environment',
      'category_ta': 'சுற்றுச்சூழல்',
      'url': 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=600&q=80',
      'date': '24-May-2026'
    },
    {
      'title_en': 'Emergency Blood Donation Camp',
      'title_ta': 'அவசர இரத்த தான முகாம்',
      'desc_en': 'Collected 85 units of blood in coordination with Kanyakumari Medical College.',
      'desc_ta': 'கன்னியாகுமரி அரசு மருத்துவக்கல்லூரி மருத்துவமனையுடன் இணைந்து 85 யூனிட் இரத்தம் சேகரிக்கப்பட்டது.',
      'category_en': 'Healthcare',
      'category_ta': 'சுகாதாரம்',
      'url': 'https://images.unsplash.com/photo-1615461066841-6116e61058f4?w=600&q=80',
      'date': '12-Apr-2026'
    },
    {
      'title_en': 'Annual Youth Football League',
      'title_ta': 'வருடாந்திர இளைஞர் கால்பந்து லீக்',
      'desc_en': 'FYC hosted 16 local teams to foster community sports and physical health.',
      'desc_ta': 'இளைஞர்களின் உடல்நலன் மேம்பட 16 உள்ளூர் அணிகள் பங்கேற்ற கால்பந்து போட்டி.',
      'category_en': 'Sports',
      'category_ta': 'விளையாட்டு',
      'url': 'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=600&q=80',
      'date': '08-Mar-2026'
    },
    {
      'title_en': 'Community Food Distribution Drive',
      'title_ta': 'சமூக உணவு வழங்கல் முகாம்',
      'desc_en': 'Provided nutritious meals to 300+ families during emergency flooding.',
      'desc_ta': 'வெள்ள பாதிப்பின் போது 300-க்கும் மேற்பட்ட குடும்பங்களுக்கு சத்தான உணவு வழங்கப்பட்டது.',
      'category_en': 'Relief',
      'category_ta': 'நிவாரணப்பணி',
      'url': 'https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?w=600&q=80',
      'date': '15-Dec-2025'
    },
    {
      'title_en': 'Beach Cleanup Campaign',
      'title_ta': 'கடற்கரை தூய்மைப்படுத்தும் பணி',
      'desc_en': 'Cleaned Colachel beach, collecting over 400kg of plastic waste.',
      'desc_ta': 'கொளச்சல் கடற்கரையை தூய்மைப்படுத்தி, 400 கிலோவிற்கும் அதிகமான பிளாஸ்டிக் கழிவுகள் அகற்றப்பட்டன.',
      'category_en': 'Cleanliness',
      'category_ta': 'தூய்மைப்பணி',
      'url': 'https://images.unsplash.com/photo-1530587191325-3db32d826c18?w=600&q=80',
      'date': '02-Oct-2025'
    },
    {
      'title_en': 'Free Education Kit Distribution',
      'title_ta': 'இலவச கல்வி உபகரணங்கள் வழங்கல்',
      'desc_en': 'Distributed textbooks, notebooks and bags to 120 underprivileged school children.',
      'desc_ta': 'வறிய சூழலில் உள்ள 120 பள்ளி குழந்தைகளுக்கு பாடப்புத்தகங்கள், நோட்டுகள் மற்றும் பைகள் வழங்கப்பட்டன.',
      'category_en': 'Education',
      'category_ta': 'கல்விச்சேவை',
      'url': 'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=600&q=80',
      'date': '15-Jun-2025'
    }
  ];

  void _showImageDetails(Map<String, String> item) {
    final isTa = _lang == 'ta';
    final title = isTa ? item['title_ta']! : item['title_en']!;
    final desc = isTa ? item['desc_ta']! : item['desc_en']!;
    final cat = isTa ? item['category_ta']! : item['category_en']!;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Image.network(
                    item['url']!,
                    fit: BoxFit.cover,
                    height: 220,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => Container(
                      height: 220,
                      color: AppColors.primarySurface,
                      child: const Center(child: Icon(Icons.broken_image, size: 48, color: AppColors.primary)),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withOpacity(0.5),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Chip(
                          label: Text(
                            cat,
                            style: const TextStyle(fontSize: 11, color: Colors.white),
                          ),
                          backgroundColor: AppColors.primary,
                        ),
                        Text(
                          item['date']!,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTa = _lang == 'ta';
    return Scaffold(
      appBar: AppBar(
        title: Text(isTa ? 'புகைப்பட கேலரி' : 'Activity Gallery'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: _photos.length,
        itemBuilder: (context, index) {
          final item = _photos[index];
          final title = isTa ? item['title_ta']! : item['title_en']!;
          final cat = isTa ? item['category_ta']! : item['category_en']!;

          return GestureDetector(
            onTap: () => _showImageDetails(item),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                boxShadow: AppTheme.cardShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Image.network(
                      item['url']!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.primarySurface,
                        child: const Center(
                          child: Icon(Icons.photo_library_outlined, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['date']!,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
