import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const NeonTransformerApp());
}

class NeonTransformerApp extends StatelessWidget {
  const NeonTransformerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi-Color Neon Transformer',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF020204),
        primaryColor: Colors.pinkAccent,
      ),
      debugShowCheckedModeBanner: false,
      home: const NeonProcessorScreen(),
    );
  }
}

class NeonProcessorScreen extends StatefulWidget {
  const NeonProcessorScreen({super.key});

  @override
  State<NeonProcessorScreen> createState() => _NeonProcessorScreenState();
}

class _NeonProcessorScreenState extends State<NeonProcessorScreen> {
  File? _imageFile;
  ui.Image? _processedNeonImage; 
  bool _isLoading = false;
  
  // نستخدم الآن "مجموعة ألوان" أو مصفوفة تدرج مبهجة بدلاً من لون واحد ثابت
  int _selectedPaletteIndex = 0;

  // مجموعات ألوان نيون مبهجة ومتناسقة جداً فندرياً
  final List<List<Color>> _neonPalettes = [
    [Colors.pinkAccent, Colors.purpleAccent, Colors.cyanAccent], // كوكتيل ساحر
    [Colors.cyanAccent, Colors.limeAccent, Colors.tealAccent],  // انتعاش فسفوري
    [Colors.amberAccent, Colors.orangeAccent, Colors.pinkAccent], // غروب النيون الدافئ
    [Colors.purpleAccent, Colors.indigoAccent, Colors.blueAccent], // غموض ليلي
  ];

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200, 
      maxHeight: 1200,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _processedNeonImage = null;
        _isLoading = true;
      });
      _renderMultiColorNeon(pickedFile.path);
    }
  }

  void _changePalette(int index) {
    if (_imageFile == null || _isLoading) return;
    setState(() {
      _selectedPaletteIndex = index;
      _isLoading = true;
    });
    _renderMultiColorNeon(_imageFile!.path);
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _renderMultiColorNeon(String path) async {
    // تجهيز الألوان المميّزة للمجموعة المختارة وتمرير قيمها الرقمية
    List<int> colorValues = _neonPalettes[_selectedPaletteIndex].map((c) => c.value).toList();

    final Uint8List? pngBytes = await compute(_convertPixelsToMultiColorNeon, {
      'path': path,
      'palette': colorValues,
    });

    if (pngBytes != null) {
      ui.decodeImageFromList(pngBytes, (ui.Image img) {
        setState(() {
          _processedNeonImage = img;
          _isLoading = false;
        });
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  // 🛠️ الخوارزمية البكسلية المتطورة لدمج الألوان المتناسقة (Spectrum Mapping)
  static Uint8List? _convertPixelsToMultiColorNeon(Map<String, dynamic> params) {
    final String path = params['path'];
    final List<dynamic> paletteRaw = params['palette'];
    final List<Color> palette = paletteRaw.map((v) => Color(v as int)).toList();

    final bytes = File(path).readAsBytesSync();
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) return null;

    int width = originalImage.width;
    int height = originalImage.height;

    img.Image gray = img.grayscale(originalImage);
    img.Image neonCanvas = img.Image(width: width, height: height);
    img.fill(neonCanvas, color: img.ColorRgba8(4, 4, 6, 255)); 

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = gray.getPixel(x, y);
        double currentLuminance = (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114) / 255.0;

        bool isLine = false;
        double intensity = 0.0;

        if (currentLuminance < 0.90) { 
          isLine = true;
          intensity = (1.0 - currentLuminance) * 1.3;
        } 
        else if (currentLuminance < 0.96) {
          if (x > 1 && x < width - 1 && y > 1 && y < height - 1) {
            final pRight = gray.getPixel(x + 1, y);
            double lumRight = (pRight.r * 0.299 + pRight.g * 0.587 + pRight.b * 0.114) / 255.0;
            if ((lumRight - currentLuminance) > 0.02) {
              isLine = true;
              intensity = (1.0 - currentLuminance) * 2.5; 
            }
          }
        }

        if (isLine) {
          intensity = intensity.clamp(0.0, 1.0);

          // ✨ السر هنا: حساب نسبة تداخل الألوان بناءً على موقع البكسل هندسياً وزاوية ميله
          // هذا يجعل الشعرات المتجاورة أو الخطوط المختلفة تتلون بتناسق رائع يتبع انحناءات الرسمة
          double factor = (x / width * 0.6) + (y / height * 0.4);
          
          // إضافة موجة جيبية خفيفة (Sine Wave) لكسر الرتابة وجعل كل خصلة شعر تختلف بشكل متناسق عن المجاورة لها
          factor += math.sin(x * 0.05 + y * 0.05) * 0.15;
          factor = factor.clamp(0.0, 0.99);

          // تحديد اللون الدقيق الممزوج من لوحة الألوان بناءً على الـ factor
          Color finalColor = _interpolateColor(palette, factor);

          int r = (finalColor.red * intensity).toInt();
          int g = (finalColor.green * intensity).toInt();
          int b = (finalColor.blue * intensity).toInt();

          neonCanvas.setPixel(x, y, img.ColorRgba8(r, g, b, 255));
        }
      }
    }

    return Uint8List.fromList(img.encodePng(neonCanvas));
  }

  // دالة رياضية لدمج ومزج قائمة من الألوان بنعومة وسلاسة (Linear Interpolation)
  static Color _interpolateColor(List<Color> colors, double t) {
    if (colors.isEmpty) return Colors.white;
    if (colors.length == 1) return colors.first;
    
    double scaledT = t * (colors.length - 1);
    int index = scaledT.floor();
    double localT = scaledT - index;
    
    if (index >= colors.length - 1) return colors.last;
    
    return Color.lerp(colors[index], colors[index + 1], localT)!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🌈 نيون مبهج متعدد الألوان 🌈', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        backgroundColor: const Color(0xFF0A0A12),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF010102),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10, width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_imageFile == null)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.palette_rounded, size: 65, color: Colors.grey[800]),
                          const SizedBox(height: 16),
                          Text('ارفع الرسمة لتشاهد سحر تداخل ألوان النيون', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                        ],
                      ),
                    if (_isLoading)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_neonPalettes[_selectedPaletteIndex].first)),
                          const SizedBox(height: 16),
                          const Text('جاري توزيع الطيف اللوني على تفاصيل الرسمة والشعر...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    if (_processedNeonImage != null && !_isLoading)
                      Positioned.fill(
                        child: InteractiveViewer(
                          maxScale: 10.0, 
                          child: CustomPaint(
                            painter: MultiColorNeonPainter(
                              neonImage: _processedNeonImage!,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          // لوحة التحكم واختيار باليتات النيون المبهجة
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            decoration: const BoxDecoration(
              color: const Color(0xFF0A0A12),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('اختر مجموعة الألوان المتناسقة للنيون:', style: TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 14),
                
                // عرض مجموعات الألوان كأزرار دائرية مدمجة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _neonPalettes.asMap().entries.map((entry) {
                    int idx = entry.key;
                    List<Color> palette = entry.value;
                    bool isSelected = _selectedPaletteIndex == idx;
                    
                    return GestureDetector(
                      onTap: () => _changePalette(idx),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: isSelected ? 52 : 40,
                        height: isSelected ? 52 : 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                          gradient: LinearGradient(
                            colors: palette,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(color: palette.first.withOpacity(0.4), blurRadius: isSelected ? 12 : 3),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickImage,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 22),
                    label: const Text('رفع الرسمة وتلوينها بالطيف الساحر', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonPalettes[_selectedPaletteIndex].first,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MultiColorNeonPainter extends CustomPainter {
  final ui.Image neonImage;

  MultiColorNeonPainter({required this.neonImage});

  @override
  void paint(Canvas canvas, Size size) {
    double scaleX = size.width / neonImage.width;
    double scaleY = size.height / neonImage.height;
    double scale = scaleX < scaleY ? scaleX : scaleY;

    double destWidth = neonImage.width * scale;
    double destHeight = neonImage.height * scale;
    double offsetX = (size.width - destWidth) / 2;
    double offsetY = (size.height - destHeight) / 2;

    Rect destRect = Rect.fromLTWH(offsetX, offsetY, destWidth, destHeight);
    Rect srcRect = Rect.fromLTWH(0, 0, neonImage.width.toDouble(), neonImage.height.toDouble());

    // طبقة التوهج الخارجي الفوسفوري المتعدد الألوان
    final paintGlow = Paint()
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0, tileMode: ui.TileMode.decal)
      ..blendMode = ui.BlendMode.plus; 

    canvas.drawImageRect(neonImage, srcRect, destRect, paintGlow);

    // طبقة ثبات حدة البكسلات الملونة الأصلية
    final paintCore = Paint()..blendMode = ui.BlendMode.screen;

    canvas.drawImageRect(neonImage, srcRect, destRect, paintCore);
  }

  @override
  bool shouldRepaint(covariant MultiColorNeonPainter oldDelegate) {
    return oldDelegate.neonImage != neonImage;
  }
}
