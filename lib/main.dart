import 'dart:async';
import 'dart:io';
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
      title: 'Neon Art Transformer',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07070C),
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
  List<List<Offset>> _extractedLines = [];
  bool _isLoading = false;
  Color _selectedNeonColor = Colors.cyanAccent;
  final ImagePicker _picker = ImagePicker();

  // مصفوفة من الألوان النيون المبهجة والمشعة
  final List<Color> _neonPalettes = [
    Colors.cyanAccent,
    Colors.pinkAccent,
    Colors.limeAccent,
    Colors.amberAccent,
    Colors.purpleAccent,
  ];

  // 1. اختيار الصورة من الاستوديو
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800, // تحديد العرض الأقصى لضمان سرعة المعالجة البكسلية
      maxHeight: 800,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _extractedLines = [];
        _isLoading = true;
      });
      
      // بدء معالجة الحواف في الخلفية
      _processImageLines(pickedFile.path);
    }
  }

  // 2. خوارزمية فحص البكسلات وتحويل الحواف المكتوبة بالقلم الرصاص إلى نقاط هندسية
  Future<void> _processImageLines(String path) async {
    // تشغيل المعالجة في Compute/Isolate لمنع تجمد الشاشة
    final List<List<Offset>> lines = await compute(_extractLinesFromImage, path);

    setState(() {
      _extractedLines = lines;
      _isLoading = false;
    });
  }

  // هذه الدالة تعمل في بيئة منفصلة بالكامل كـ Isolate لشحذ الأداء
  static List<List<Offset>> _extractLinesFromImage(String filePath) {
    final bytes = File(filePath).readAsBytesSync();
    final img.Image? originalImage = img.decodeImage(bytes);
    
    if (originalImage == null) return [];

    List<List<Offset>> detectedLines = [];
    // تحويل الصورة إلى تدرج رمادي لتسهيل قراءة خطوط الرصاص
    final grayscale = img.grayscale(originalImage);
    
    int width = grayscale.width;
    int height = grayscale.height;
    
    // مصفوفة لتتبع البكسلات التي تمت زيارتها لمنع التكرار
    List<List<bool>> visited = List.generate(width, (_) => List.filled(height, false));

    // حد العتبة (Threshold): خطوط الرصاص تكون داكنة مقارنة بالخلفية البيضاء
    // في مكتبة image، القيمة تكون رمادية بين 0 و 255
    const int threshold = 130; 

    // خوارزمية بسيطة لتتبع الخطوط المتصلة (Flood Fill / Line Tracking)
    for (int x = 2; x < width - 2; x += 2) {
      for (int y = 2; y < height - 2; y += 2) {
        final pixel = grayscale.getPixel(x, y);
        // حساب شدة اللمعان (Luminance) للبكسل
        final num luminance = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114;

        if (luminance < threshold && !visited[x][y]) {
          List<Offset> currentLine = [];
          _trackLine(x, y, grayscale, visited, currentLine, threshold);
          if (currentLine.length > 3) { // تجاهل النقاط الصغيرة جداً أو النويز
            detectedLines.add(currentLine);
          }
        }
      }
    }
    return detectedLines;
  }

  // تتبع النقاط المجاورة المظلمة لبناء مسار خطي مستمر
  static void _trackLine(int startX, int startY, img.Image image, List<List<bool>> visited, List<Offset> currentLine, int threshold) {
    List<PointInt> queue = [PointInt(startX, startY)];
    visited[startX][startY] = true;

    int width = image.width;
    int height = image.height;

    while (queue.isNotEmpty) {
      PointInt p = queue.removeLast();
      currentLine.add(Offset(p.x.toDouble(), p.y.toDouble()));

      // فحص الجيران في الاتجاهات الثمانية
      for (int dx = -2; dx <= 2; dx += 2) {
        for (int dy = -2; dy <= 2; dy += 2) {
          int nx = p.x + dx;
          int ny = p.y + dy;

          if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
            if (!visited[nx][ny]) {
              final px = image.getPixel(nx, ny);
              final num lum = px.r * 0.299 + px.g * 0.587 + px.b * 0.114;
              if (lum < threshold) {
                visited[nx][ny] = true;
                queue.add(PointInt(nx, ny));
              }
            }
          }
        }
      }
      if (currentLine.length > 150) break; // إيقاف الخطوط الطويلة جداً لضمان توزيع هندسي سلس
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✨ محول النيون السحري ✨', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F1E),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // لوحة العرض الرئيسية
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF020205),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _selectedNeonColor.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _selectedNeonColor.withOpacity(0.1),
                      blurRadius: 30,
                      spreadRadius: 2,
                    )
                  ]
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_imageFile == null)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_note_rounded, size: 80, color: Colors.grey[700]),
                          const SizedBox(height: 16),
                          Text('ارفع صورة رسمة القلم الرصاص البدء', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                        ],
                      ),
                    if (_isLoading)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_selectedNeonColor)),
                          const SizedBox(height: 16),
                          const Text('جاري قراءة الحواف وتحويلها لنيون مشع...', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    if (_imageFile != null && !_isLoading)
                      Positioned.fill(
                        child: InteractiveViewer(
                          maxScale: 5.0,
                          child: CustomPaint(
                            painter: AdvancedNeonPainter(
                              lines: _extractedLines,
                              neonColor: _selectedNeonColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // لوحة التحكم السفلية لتغيير الألوان والأدوات
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: const BoxDecoration(
              color: const Color(0xFF0F0F1E),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('اختر لون النيون المبهج والمشّع:', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                // قائمة الألوان المشعة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _neonPalettes.map((color) {
                    bool isSelected = _selectedNeonColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedNeonColor = color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: isSelected ? 48 : 36,
                        height: isSelected ? 48 : 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.6),
                              blurRadius: isSelected ? 16 : 4,
                              spreadRadius: isSelected ? 2 : 0,
                            )
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                // زر رفع واختيار الصورة
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickImage,
                    icon: const Icon(Icons.cloud_upload_rounded, size: 24),
                    label: const Text('رفع رسمة قلم رصاص', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedNeonColor,
                      foregroundColor: Colors.black,
                      elevation: 8,
                      shadowColor: _selectedNeonColor.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

// كلاس مساعد لتمثيل نقطة صحيحة في خوارزمية الـ Image Processing
class PointInt {
  final int x;
  final int y;
  PointInt(this.x, this.y);
}

// 3. الرسام الاحترافي المتعدد الطبقات لإنتاج توهج النيون الفلوري الناعم
class AdvancedNeonPainter extends CustomPainter {
  final List<List<Offset>> lines;
  final Color neonColor;

  AdvancedNeonPainter({required this.lines, required this.neonColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) return;

    // إيجاد أبعاد النقاط لمطابقتها مع مساحة الرسم المعطاة (Scaling & Normalization)
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (var line in lines) {
      for (var pt in line) {
        if (pt.dx < minX) minX = pt.dx;
        if (pt.dy < minY) minY = pt.dy;
        if (pt.dx > maxX) maxX = pt.dx;
        if (pt.dy > maxY) maxY = pt.dy;
      }
    }

    double contentWidth = maxX - minX;
    double contentHeight = maxY - minY;
    
    if (contentWidth == 0 || contentHeight == 0) return;

    // حساب نسبة التكبير المناسبة لملء الحاوية بشكل متناسق مع ترك هوامش (Padding)
    double scaleX = (size.width - 40) / contentWidth;
    double scaleY = (size.height - 40) / contentHeight;
    double scale = scaleX < scaleY ? scaleX : scaleY;

    double offsetX = (size.width - contentWidth * scale) / 2 - minX * scale;
    double offsetY = (size.height - contentHeight * scale) / 2 - minY * scale;

    // تحويل النقاط المكتشفة إلى كائنات Path مدعومة من محرك سكايا للرسم بـ Flutter
    List<Path> paths = [];
    for (var line in lines) {
      if (line.isEmpty) continue;
      Path p = Path();
      p.moveTo(line[0].dx * scale + offsetX, line[0].dy * scale + offsetY);
      for (int i = 1; i < line.length; i++) {
        p.lineTo(line[i].dx * scale + offsetX, line[i].dy * scale + offsetY);
      }
      paths.add(p);
    }

    // الرسم عبر 3 طبقات للحصول على محاكاة فيزيائية حقيقية لأنابيب غاز النيون
    for (var path in paths) {
      // الطبقة أ: التوهج الخارجي الفوسفوري العريض جداً (Deep Ambient Glow)
      final ambientGlow = Paint()
        ..color = neonColor.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 18);
      canvas.drawPath(path, ambientGlow);

      // الطبقة ب: التوهج النيوني المتوسط والمركز (Intense Core Glow)
      final coreGlow = Paint()
        ..color = neonColor.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 5);
      canvas.drawPath(path, coreGlow);

      // الطبقة ج: قلب الضوء الساطع الأبيض (Incandescent Core)
      final electricCore = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3.5;
      canvas.drawPath(path, electricCore);
    }
  }

  @override
  bool shouldRepaint(covariant AdvancedNeonPainter oldDelegate) {
    return oldDelegate.lines != lines || oldDelegate.neonColor != neonColor;
  }
}
