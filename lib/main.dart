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
        scaffoldBackgroundColor: const Color(0xFF050508),
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
      maxWidth: 600, 
      maxHeight: 600,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _extractedLines = [];
        _isLoading = true;
      });
      _processImageLines(pickedFile.path);
    }
  }

  Future<void> _processImageLines(String path) async {
    final List<List<Offset>> lines = await compute(_extractHighQualityLines, path);
    setState(() {
      _extractedLines = lines;
      _isLoading = false;
    });
  }

  static List<List<Offset>> _extractHighQualityLines(String filePath) {
    final bytes = File(filePath).readAsBytesSync();
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) return [];

    img.Image processed = img.grayscale(originalImage);
    processed = img.gaussianBlur(processed, radius: 2); 

    int width = processed.width;
    int height = processed.height;
    
    List<List<bool>> visited = List.generate(width, (_) => List.filled(height, false));
    List<List<Offset>> detectedLines = [];
    const int threshold = 130; 

    for (int x = 2; x < width - 2; x += 1) {
      for (int y = 2; y < height - 2; y += 1) {
        final pixel = processed.getPixel(x, y);
        final double luminance = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114;

        if (luminance < threshold && !visited[x][y]) {
          List<Offset> currentLine = [];
          List<PointInt> queue = [PointInt(x, y)];
          visited[x][y] = true;

          while (queue.isNotEmpty) {
            PointInt p = queue.removeLast();
            if (currentLine.isEmpty || (Offset(p.x.toDouble(), p.y.toDouble()) - currentLine.last).distance > 4) {
              currentLine.add(Offset(p.x.toDouble(), p.y.toDouble()));
            }

            for (int dx = -2; dx <= 2; dx += 1) {
              for (int dy = -2; dy <= 2; dy += 1) {
                int nx = p.x + dx;
                int ny = p.y + dy;

                if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
                  if (!visited[nx][ny]) {
                    final px = processed.getPixel(nx, ny);
                    final double nLum = px.r * 0.299 + px.g * 0.587 + px.b * 0.114;
                    if (nLum < threshold) {
                      visited[nx][ny] = true;
                      queue.add(PointInt(nx, ny));
                    }
                  }
                }
              }
            }
            if (currentLine.length > 250) break;
          }

          if (currentLine.length > 6) {
            detectedLines.add(currentLine);
          }
        }
      }
    }
    return detectedLines;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✨ محول النيون الاحترافي ✨', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0A0A12),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF010103),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _selectedNeonColor.withOpacity(0.2), width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_imageFile == null)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.brush_rounded, size: 70, color: Colors.grey[800]),
                          const SizedBox(height: 16),
                          Text('ارفع رسمة القلم الرصاص لرؤية السحر', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                        ],
                      ),
                    if (_isLoading)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_selectedNeonColor)),
                          const SizedBox(height: 16),
                          const Text('جاري تنعيم الحواف وتحويلها لنيون عالي الدقة...', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    if (_imageFile != null && !_isLoading)
                      Positioned.fill(
                        child: InteractiveViewer(
                          maxScale: 5.0,
                          child: CustomPaint(
                            painter: HighFidelityNeonPainter(
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: const BoxDecoration(
              color: const Color(0xFF0A0A12),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('اختر لون النيون المبهج والمشّع:', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _neonPalettes.map((color) {
                    bool isSelected = _selectedNeonColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedNeonColor = color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isSelected ? 46 : 34,
                        height: isSelected ? 46 : 34,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                          boxShadow: [
                            BoxShadow(color: color.withOpacity(0.5), blurRadius: isSelected ? 14 : 4),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickImage,
                    icon: const Icon(Icons.add_photo_alternate_rounded, size: 22),
                    label: const Text('رفع رسمة قلم رصاص', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedNeonColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 6,
                      shadowColor: _selectedNeonColor.withOpacity(0.3),
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

class PointInt {
  final int x;
  final int y;
  PointInt(this.x, this.y);
}

// الرسام الاحترافي: تم تعديله ليدعم خوارزمية البيزيه لتنعيم الخطوط المتوافقة مع جميع الإصدارات
class HighFidelityNeonPainter extends CustomPainter {
  final List<List<Offset>> lines;
  final Color neonColor;

  HighFidelityNeonPainter({required this.lines, required this.neonColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) return;

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
    if (contentWidth <= 0 || contentHeight <= 0) return;

    double scaleX = (size.width - 40) / contentWidth;
    double scaleY = (size.height - 40) / contentHeight;
    double scale = scaleX < scaleY ? scaleX : scaleY;

    double offsetX = (size.width - contentWidth * scale) / 2 - minX * scale;
    double offsetY = (size.height - contentHeight * scale) / 2 - minY * scale;

    List<Path> smoothedPaths = [];
    for (var line in lines) {
      if (line.length < 2) continue;

      final points = line.map((p) => 
        Offset(p.dx * scale + offsetX, p.dy * scale + offsetY)
      ).toList();

      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);

      // تطبيق تنعيم يدوي فائق الانسيابية (Quadratic Bézier Smoothing)
      for (int i = 0; i < points.length - 1; i++) {
        final xc = (points[i].dx + points[i + 1].dx) / 2;
        final yc = (points[i].dy + points[i + 1].dy) / 2;
        path.quadraticBezierTo(points[i].dx, points[i].dy, xc, yc);
      }
      
      // توصيل النقطة الأخيرة
      path.lineTo(points.last.dx, points.last.dy);
      smoothedPaths.add(path);
    }

    // رسم طبقات النيون المتوهجة الثلاثية الاحترافية
    for (var path in smoothedPaths) {
      // 1. التوهج الخارجي العريض الفوسفوري
      final outerGlow = Paint()
        ..color = neonColor.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 12);
      canvas.drawPath(path, outerGlow);

      // 2. توهج قلب الغاز الكثيف
      final innerGlow = Paint()
        ..color = neonColor.withOpacity(0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 3);
      canvas.drawPath(path, innerGlow);

      // 3. قلب النيون الأبيض الكهربائي شديد السطوع
      final electricCore = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2.0; 
      canvas.drawPath(path, electricCore);
    }
  }

  @override
  bool shouldRepaint(covariant HighFidelityNeonPainter oldDelegate) {
    return oldDelegate.lines != lines || oldDelegate.neonColor != neonColor;
  }
}
