import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img; // مكتبة معالجة البيكسلات
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MaterialApp(
    home: NeonTransformerPage(),
    debugShowCheckedModeBanner: false,
  ));
}

class NeonTransformerPage extends StatefulWidget {
  const NeonTransformerPage({super.key});

  @override
  _NeonTransformerPageState createState() => _NeonTransformerPageState();
}

class _NeonTransformerPageState extends State<NeonTransformerPage> {
  File? _imageFile;
  Uint8List? _neonImageBytes;
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  // دالة اختيار الصورة وبدء التحويل
  Future<void> _pickAndTransform() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      _imageFile = File(pickedFile.path);
      _isProcessing = true;
      _neonImageBytes = null;
    });

    // تشغيل المعالجة الثقيلة في الـ Isolate الخلفي لحفظ سلاسة التطبيق
    final Uint8List result = await compute(_convertToMultiColorNeon, _imageFile!);

    setState(() {
      _neonImageBytes = result;
      _isProcessing = false;
    });
  }

  // الـ Isolate المسؤول عن تحويل البكسلات وتوليد النيون متعدد الألوان
  static Uint8List _convertToMultiColorNeon(File file) {
    final bytes = file.readAsBytesSync();
    final img.Image? src = img.decodeImage(bytes);
    if (src == null) return Uint8List(0);

    // 1. تصغير الصورة قليلاً لتسريع المعالجة وتحسين سماكة خطوط النيون
    final img.Image resized = img.copyResize(src, width: 600);
    
    // 2. إنشاء صورة فارغة بخلفية سوداء بالكامل لوضع النيون عليها
    final img.Image neonScene = img.Image(width: resized.width, height: resized.height);
    img.fill(neonScene, color: img.ColorRgb8(5, 5, 12)); // أسود داكن جداً لقاع النيون

    // 3. خوارزمية كشف الحواف مع الحفاظ على الألوان وتضخيمها (Sobel Neon Multi-Color)
    for (int y = 1; y < resized.height - 1; y++) {
      for (int x = 1; x < resized.width - 1; x++) {
        
        // حساب التباين للحواف عبر مصفوفة سوبل (Sobel Operators)
        double gxR = 0, gyR = 0;
        double gxG = 0, gyG = 0;
        double gxB = 0, gyB = 0;

        for (int cy = -1; cy <= 1; cy++) {
          for (int cx = -1; cx <= 1; cx++) {
            final pixel = resized.getPixel(x + cx, y + cy);
            
            // مصفوفة سوبل للأفق والعمود
            final int kx = (cx == 0) ? (cy == 0 ? 0 : cx * 2) : cx;
            final int ky = (cy == 0) ? (cx == 0 ? 0 : cy * 2) : cy;

            gxR += pixel.r * kx; gyR += pixel.r * ky;
            gxG += pixel.g * kx; gyG += pixel.g * ky;
            gxB += pixel.b * kx; gyB += pixel.b * ky;
          }
        }

        // حساب شدة الحافة لكل قناة لونية بشكل مستقل
        final double edgeR = math.sqrt(gxR * gxR + gyR * gyR);
        final double edgeG = math.sqrt(gxG * gxG + gyG * gyG);
        final double edgeB = math.sqrt(gxB * gxB + gyB * gyB);

        // دمج الشدة الإجمالية للحافة
        final double totalEdge = (edgeR + edgeG + edgeB) / 3;

        // حد العتبة (Threshold) لعزل الحواف الحادة فقط مثل الرسم التوضيحي
        if (totalEdge > 45) {
          final currentPixel = resized.getPixel(x, y);
          
          // استخلاص اللون السائد للبكسل لجعله هو لون النيون الخاص به
          int r = currentPixel.r.toInt();
          int g = currentPixel.g.toInt();
          int b = currentPixel.b.toInt();

          // تشبيع وتضخيم الألوان (Color Saturation Boost) لجعلها فسفورية مشعة
          double maxC = [r, g, b].reduce((a, b) => a > b ? a : b).toDouble();
          if (maxC > 0) {
            r = ((r / maxC) * 255).clamp(0, 255).toInt();
            g = ((g / maxC) * 255).clamp(0, 255).toInt();
            b = ((b / maxC) * 255).clamp(0, 255).toInt();
          }

          // رسم الحافة الملونة المشبعة على الخلفية السوداء
          neonScene.setPixel(x, y, img.ColorRgb8(r, g, b));
        }
      }
    }

    // 4. تطبيق فلتر التمويه (Gaussian Blur) لمحاكاة توهج ضوء النيون للخلفية
    final img.Image glowLayer = img.gaussianBlur(neonScene, radius: 3);

    // 5. دمج الحواف الحادة الساطعة فوق طبقة التمويه للحصول على تأثير الـ Core المضيء
    for (int y = 0; y < neonScene.height; y++) {
      for (int x = 0; x < neonScene.width; x++) {
        final pCore = neonScene.getPixel(x, y);
        if (pCore.r > 0 || pCore.g > 0 || pCore.b > 0) {
          // جعل قلب الخط مائل للبياض ليعطي انطباع الإضاءة الحقيقية
          final int nr = (pCore.r * 0.4 + 153).clamp(0, 255).toInt();
          final int ng = (pCore.g * 0.4 + 153).clamp(0, 255).toInt();
          final int nb = (pCore.b * 0.4 + 153).clamp(0, 255).toInt();
          glowLayer.setPixel(x, y, img.ColorRgb8(nr, ng, nb));
        }
      }
    }

    // تصدير الصورة النهائية بصيغة PNG
    return Uint8List.fromList(img.encodePng(glowLayer));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05050C), // خلفية داكنة جداً لإبراز النيون
      appBar: AppBar(
        title: const Text('محول النيون الذكي الآلي', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isProcessing)
                const Column(
                  children: [
                    CircularProgressIndicator(color: Colors.cyanAccent),
                    SizedBox(height: 16),
                    Text('جاري تحليل الألوان وعزل الحواف الفسفورية...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              if (_neonImageBytes == null && !_isProcessing)
                const Icon(Icons.blur_on, size: 100, color: Colors.cyanAccent),
              if (_neonImageBytes != null && !_isProcessing)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.memory(_neonImageBytes!, fit: BoxFit.contain),
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _isProcessing ? null : _pickAndTransform,
                icon: const Icon(Icons.photo_library),
                label: const Text('اختر صورة لتحويلها فوراً', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
