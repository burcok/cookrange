import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../core/services/dish_seeder_service.dart';
import '../core/services/dish_image_service.dart';
import '../core/data/dish_data.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Init error: $e');
  }

  runApp(const SeederApp());
}

class SeederApp extends StatelessWidget {
  const SeederApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cookrange Manual Seeder',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        useMaterial3: true,
      ),
      home: const SeederScreen(),
    );
  }
}

class SeederScreen extends StatefulWidget {
  const SeederScreen({super.key});

  @override
  State<SeederScreen> createState() => _SeederScreenState();
}

class _SeederScreenState extends State<SeederScreen> {
  final DishSeederService _seederService = DishSeederService();
  final DishImageService _imageService = DishImageService();

  int _currentIndex = 0;
  String? _currentImageUrl;
  bool _isLoading = false;
  String _currentSource =
      'loremflickr'; // 'loremflickr', 'pixabay', 'themealdb', 'foodish', 'unsplash', 'picsum'
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  String _imageKey = ''; // Used to force image rebuild

  List<Map<String, dynamic>> get _dishes => allDishes;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(() => setState(() {}));
    _urlController.addListener(() => setState(() {}));
    _loadDish(_currentIndex);
  }

  @override
  void dispose() {
    _queryController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadDish(int index) async {
    if (index < 0 || index >= _dishes.length) return;

    setState(() {
      _isLoading = true;
      _currentIndex = index;
      _queryController.text = _dishes[index]['name_en'];
      _urlController.clear();
      _currentImageUrl = null;
    });

    await _fetchImage();
  }

  Future<void> _fetchImage() async {
    setState(() => _isLoading = true);

    final imageUrl = await _imageService.fetchDishImage(_queryController.text,
        source: _currentSource);

    setState(() {
      _currentImageUrl = imageUrl;
      _urlController.text = imageUrl ?? '';
      _imageKey = DateTime.now().millisecondsSinceEpoch.toString();
      _isLoading = false;
    });
  }

  Future<void> _saveAndNext() async {
    final finalUrl = _urlController.text.trim();
    if (finalUrl.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _seederService.seedSingleDish(_dishes[_currentIndex], finalUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Successfully seeded!'),
            duration: Duration(milliseconds: 500)),
      );
      if (_currentIndex < _dishes.length - 1) {
        _loadDish(_currentIndex + 1);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleSource() {
    setState(() {
      final sources = [
        'loremflickr',
        'pixabay',
        'themealdb',
        'foodish',
        'unsplash',
        'picsum'
      ];
      int idx = sources.indexOf(_currentSource);
      _currentSource = sources[(idx + 1) % sources.length];
    });
    _fetchImage();
  }

  Future<void> _openInBrowser() async {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _openGoogleImages() async {
    final query = _queryController.text.trim();
    if (query.isNotEmpty) {
      final searchUrl =
          'https://www.google.com/search?q=${Uri.encodeComponent(query)}+food+dish&tbm=isch';
      final uri = Uri.parse(searchUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= _dishes.length) {
      return const Scaffold(body: Center(child: Text('All dishes completed!')));
    }

    final dish = _dishes[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Seeding: ${_currentIndex + 1} / ${_dishes.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: () => _loadDish(_currentIndex + 1),
            tooltip: 'Skip',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              dish['name'],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Not: Sürekli 503 alıyorsanız sayfayı yenilemeyi deneyin.',
              style: TextStyle(color: Colors.red[300], fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              dish['description'],
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Image Preview Area
            Container(
              height: 400,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _currentImageUrl != null
                        ? Image.network(
                            _currentImageUrl!,
                            key: ValueKey('$_currentImageUrl-$_imageKey'),
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                  child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline,
                                        size: 48, color: Colors.red),
                                    const SizedBox(height: 8),
                                    Text('Yükleme Hatası (503/404)',
                                        style:
                                            TextStyle(color: Colors.red[700])),
                                    TextButton(
                                      onPressed: _openInBrowser,
                                      child: const Text('Tarayıcıda Dene'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        : const Center(child: Text('Resim Bulunamadı')),
              ),
            ),

            const SizedBox(height: 24),

            // Search Control
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                labelText: 'Arama Sorgusu (EN)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _fetchImage,
                ),
              ),
              onSubmitted: (_) => _fetchImage(),
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Resim URL (Manuel veya Otomatik)',
                hintText: 'https://...',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 20),
                      onPressed: _openInBrowser,
                      tooltip: 'Tarayıcıda Aç',
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _currentImageUrl = _urlController.text.trim();
                        });
                      },
                    ),
                  ],
                ),
              ),
              onChanged: (val) {
                // Optionally update preview on change,
                // but let's use the explicit button to avoid too many reloads
              },
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Mevcut Kaynak: ${_currentSource.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sorgu: ${_queryController.text}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_currentSource == 'unsplash') ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.warning, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    '503 Riski',
                    style: TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleSource,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Kaynak Değiştir'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue[50],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openGoogleImages,
                    icon: const Icon(Icons.search),
                    label: const Text('Google Resimleri'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _fetchImage,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Yeniden Çek'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.orange[50],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _urlController.text.isNotEmpty && !_isLoading
                  ? _saveAndNext
                  : null,
              icon: const Icon(Icons.check_circle),
              label: const Text('Doğru (Kaydet ve Sonraki)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 40),
            // Quick Navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _currentIndex > 0
                      ? () => _loadDish(_currentIndex - 1)
                      : null,
                  child: const Text('Önceki'),
                ),
                Text('Dish ID: ${dish['id']}'),
                TextButton(
                  onPressed: _currentIndex < _dishes.length - 1
                      ? () => _loadDish(_currentIndex + 1)
                      : null,
                  child: const Text('Sonraki'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
