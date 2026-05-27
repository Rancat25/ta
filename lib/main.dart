import 'dart:io';
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
      title: 'Neon Ultra Fidelity',
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
  Color _selectedNeonColor = Colors.pinkAccent;
  final ImagePicker _picker = ImagePicker();

  final List<Color> _neonPalettes = [
    Colors.pinkAccent,
    Colors.cyanAccent,
    Colors.limeAccent,
    Colors.amberAccent,
    Colors.purpleAccent,
  ];

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200, // رفع الدقة لـ 1200 لضمان عدم ضياع أي بكسل رفيع
      maxHeight: 1200,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _processedNeonImage = null;
        _isLoading = true;
      });
      _renderNeonImage(pickedFile.path, _selectedNeonColor);
    }
  }

  void _updateNeonColor(Color newColor) {
    if (_imageFile == null || _isLoading) return;
    setState(() {
      _selectedNeonColor = newColor;
      _isLoading = true;
    });
    _renderNeonImage(_imageFile!.path, newColor);
  }

  Future<void> _renderNeonImage(String path, Color neonColor) async {
    final Uint8List? pngBytes = await compute(_convertAllLinesToNeon, {
      'path': path,
      'color': neonColor.value,
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

  // 🛠️ الخوارزمية المطورة جداً لالتقاط تفاصيل الخطوط مهما كانت نحيفة (Fidelity Max)
  static Uint8List? _convertAllLinesToNeon(Map<String, dynamic> params) {
    final String path = params['path'];
    final int colorValue = params['color'];
    final Color selectedColor = Color(colorValue);

    final bytes = File(path).readAsBytesSync();
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) return null;

    int width = originalImage.width;
    int height = originalImage.height;

    // 1. تحويل الصورة إلى التدرج الرمادي بدون أي بلور (تنعيم) للحفاظ على الخطوط النحيفة كالشعر
    img.Image gray = img.grayscale(originalImage);

    // 2. إنشاء الكانفاس الأسود بالكامل للخلفية
    img.Image neonCanvas = img.Image(width: width, height: height);
    img.fill(neonCanvas, color: img.ColorRgba8(5, 5, 8, 255)); 

    // 3. الفحص البكسلي المتقدم المعتمد على التباين الموضعي
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = gray.getPixel(x, y);
        double currentLuminance = (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114) / 255.0;

        // خوارزمية ذكية: نتحقق من محيط البكسل لمعرفة ما إذا كان جزءاً من خط رفيع
        // نقوم بحساب التباين المباشر مقارنة بمتوسط إضاءة الورقة حوله
        bool isLine = false;
        double intensity = 0.0;

        // إذا كان البكسل داكناً بشكل عام (الخطوط العريضة)
        if (currentLuminance < 0.90) { 
          isLine = true;
          intensity = (1.0 - currentLuminance) * 1.2; // تعزيز الإضاءة للخطوط الرمادية
        } 
        // التقط الخطوط الرفيعة جداً (حتى لو كانت رمادية فاتحة على خلفية رمادية)
        else if (currentLuminance < 0.96) {
          // فحص عينة سريعة من الجيران للتأكد أنه خط وليس نويز
          if (x > 1 && x < width - 1 && y > 1 && y < height - 1) {
            final pRight = gray.getPixel(x + 1, y);
            double lumRight = (pRight.r * 0.299 + pRight.g * 0.587 + pRight.b * 0.114) / 255.0;
            
            // إذا كان البكسل الحالي أدكن من جاره بأكثر من 2%، إذن هو خط رفيع جداً!
            if ((lumRight - currentLuminance) > 0.02) {
              isLine = true;
              intensity = (1.0 - currentLuminance) * 2.5; // مضاعفة القوة للخطوط الرفيعة لتظهر بوضوح مشع
            }
          }
        }

        if (isLine) {
          intensity = intensity.clamp(0.0, 1.0);

          // دمج بكسل النيون المشع مع الحفاظ المطلق على الحجم الأصلي (بكسل مقابل بكسل)
          int r = (selectedColor.red * intensity).toInt();
          int g = (selectedColor.green * intensity).toInt();
          int b = (selectedColor.blue * intensity).toInt();

          neonCanvas.setPixel(x, y, img.ColorRgba8(r, g, b, 255));
        }
      }
    }

    return Uint8List.fromList(img.encodePng(neonCanvas));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✨ نيون فائق الدقة والتفاصيل ✨', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
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
                  border: Border.all(color: _selectedNeonColor.withOpacity(0.15), width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_imageFile == null)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_filter_rounded, size: 65, color: Colors.grey[800]),
                          const SizedBox(height: 16),
                          Text('ارفع الرسمة لالتقاط كل تفصيلة وخط', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                        ],
                      ),
                    if (_isLoading)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_selectedNeonColor)),
                          const SizedBox(height: 16),
                          const Text('جاري تحليل الخطوط الرفيعة بدقة بكسلية مجهرية...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    if (_processedNeonImage != null && !_isLoading)
                      Positioned.fill(
                        child: InteractiveViewer(
                          maxScale: 10.0, // زيادة الزووم لعشرة أضعاف لفحص التفاصيل الخارقة
                          child: CustomPaint(
                            painter: UltraFidelityNeonPainter(
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            decoration: const BoxDecoration(
              color: const Color(0xFF0A0A12),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تغيير لون النيون المشع فورياً:', style: TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _neonPalettes.map((color) {
                    bool isSelected = _selectedNeonColor == color;
                    return GestureDetector(
                      onTap: () => _updateNeonColor(color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isSelected ? 44 : 32,
                        height: isSelected ? 44 : 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
                          boxShadow: [
                            BoxShadow(color: color.withOpacity(0.4), blurRadius: isSelected ? 12 : 3),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickImage,
                    icon: const Icon(Icons.flash_on_rounded, size: 22),
                    label: const Text('رفع وتألق الرسمة بالكامل', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedNeonColor,
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

class UltraFidelityNeonPainter extends CustomPainter {
  final ui.Image neonImage;

  UltraFidelityNeonPainter({required this.neonImage});

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

    // طبقة 1: التوهج المحيطي الفوسفوري الذكي (Glow Sigma مُعدّل ليكون ناعماً ولا يطمس الخطوط القريبة)
    final paintGlow = Paint()
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0, tileMode: ui.TileMode.decal)
      ..blendMode = ui.BlendMode.plus; 

    canvas.drawImageRect(neonImage, srcRect, destRect, paintGlow);

    // طبقة 2: طبقة حدة وثبات التفاصيل الرفيعة (The Core Lines)
    final paintCore = Paint()..blendMode = ui.BlendMode.screen;

    canvas.drawImageRect(neonImage, srcRect, destRect, paintCore);
  }

  @override
  bool shouldRepaint(covariant UltraFidelityNeonPainter oldDelegate) {
    return oldDelegate.neonImage != neonImage;
  }
}
