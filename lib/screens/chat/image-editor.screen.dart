import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

enum DrawingTool { pen, highlighter, eraser }

class ImageEditorScreen extends StatefulWidget {
  final File imageFile;

  const ImageEditorScreen({
    super.key,
    required this.imageFile,
  });

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  final GlobalKey _imageKey = GlobalKey();
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  
  DrawingTool _currentTool = DrawingTool.pen;
  Color _penColor = Colors.black;
  Color _highlighterColor = Colors.yellow.withOpacity(0.5);
  double _penStrokeWidth = 3.0;
  double _highlighterStrokeWidth = 15.0;
  double _eraserStrokeWidth = 20.0;

  List<DrawingPath> _paths = [];
  List<DrawingPath> _redoStack = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Image',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          // Undo button
          IconButton(
            icon: Icon(
              Icons.undo,
              color: _paths.isEmpty ? Colors.grey : Colors.white,
            ),
            onPressed: _paths.isEmpty ? null : _undo,
          ),
          // Redo button
          IconButton(
            icon: Icon(
              Icons.redo,
              color: _redoStack.isEmpty ? Colors.grey : Colors.white,
            ),
            onPressed: _redoStack.isEmpty ? null : _redo,
          ),
          // Send button
          IconButton(
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: _saveAndSend,
          ),
        ],
      ),
      body: Column(
        children: [
          // Image with drawing canvas
          Expanded(
            child: RepaintBoundary(
              key: _repaintBoundaryKey,
              child: Stack(
                children: [
                  // Background image
                  Center(
                    child: Image.file(
                      widget.imageFile,
                      fit: BoxFit.contain,
                      key: _imageKey,
                    ),
                  ),
                  // Drawing canvas
                  CustomPaint(
                    painter: DrawingPainter(List.from(_paths)), // Create new list to force repaint
                    size: Size.infinite,
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Tool selection
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildToolButton(
                      icon: Icons.edit,
                      label: 'Pen',
                      tool: DrawingTool.pen,
                      isSelected: _currentTool == DrawingTool.pen,
                    ),
                    _buildToolButton(
                      icon: Icons.highlight,
                      label: 'Highlight',
                      tool: DrawingTool.highlighter,
                      isSelected: _currentTool == DrawingTool.highlighter,
                    ),
                    _buildToolButton(
                      icon: Icons.auto_fix_high,
                      label: 'Eraser',
                      tool: DrawingTool.eraser,
                      isSelected: _currentTool == DrawingTool.eraser,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Color picker for pen
                if (_currentTool == DrawingTool.pen)
                  _buildColorPicker([
                    Colors.black,
                    Colors.red,
                    Colors.blue,
                    Colors.green,
                    Colors.yellow,
                    Colors.orange,
                    Colors.purple,
                    Colors.pink,
                  ], _penColor, (color) {
                    setState(() => _penColor = color);
                  }),
                // Color picker for highlighter
                if (_currentTool == DrawingTool.highlighter)
                  _buildColorPicker([
                    Colors.yellow.withOpacity(0.5),
                    Colors.green.withOpacity(0.5),
                    Colors.blue.withOpacity(0.5),
                    Colors.pink.withOpacity(0.5),
                    Colors.orange.withOpacity(0.5),
                    Colors.purple.withOpacity(0.5),
                    Colors.red.withOpacity(0.5),
                    Colors.cyan.withOpacity(0.5),
                  ], _highlighterColor, (color) {
                    setState(() => _highlighterColor = color);
                  }),
                // Stroke width slider
                if (_currentTool != DrawingTool.eraser)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Text(
                          'Stroke Width: ${_getStrokeWidth().toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        Slider(
                          value: _getStrokeWidth(),
                          min: 1,
                          max: _currentTool == DrawingTool.pen ? 10 : 30,
                          divisions: _currentTool == DrawingTool.pen ? 9 : 29,
                          activeColor: Colors.white,
                          onChanged: (value) {
                            setState(() {
                              if (_currentTool == DrawingTool.pen) {
                                _penStrokeWidth = value;
                              } else {
                                _highlighterStrokeWidth = value;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                // Eraser size slider
                if (_currentTool == DrawingTool.eraser)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Text(
                          'Eraser Size: ${_eraserStrokeWidth.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        Slider(
                          value: _eraserStrokeWidth,
                          min: 5,
                          max: 50,
                          divisions: 45,
                          activeColor: Colors.white,
                          onChanged: (value) {
                            setState(() => _eraserStrokeWidth = value);
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required DrawingTool tool,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() => _currentTool = tool);
        _redoStack.clear(); // Clear redo stack when switching tools
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker(
    List<Color> colors,
    Color selectedColor,
    ValueChanged<Color> onColorSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: colors.map((color) {
          final isSelected = _colorsEqual(color, selectedColor);
          return GestureDetector(
            onTap: () => onColorSelected(color),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _colorsEqual(Color a, Color b) {
    return a.value == b.value;
  }

  double _getStrokeWidth() {
    switch (_currentTool) {
      case DrawingTool.pen:
        return _penStrokeWidth;
      case DrawingTool.highlighter:
        return _highlighterStrokeWidth;
      case DrawingTool.eraser:
        return _eraserStrokeWidth;
    }
  }

  Color _getColor() {
    switch (_currentTool) {
      case DrawingTool.pen:
        return _penColor;
      case DrawingTool.highlighter:
        return _highlighterColor;
      case DrawingTool.eraser:
        return Colors.black; // Color doesn't matter for eraser, but set it for consistency
    }
  }

  void _onPanStart(DragStartDetails details) {
    final RenderBox? renderBox =
        _repaintBoundaryKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.globalToLocal(details.globalPosition);
    final path = DrawingPath(
      points: [offset],
      color: _getColor(),
      strokeWidth: _getStrokeWidth(),
      tool: _currentTool,
    );
    setState(() {
      // Create a new list to trigger repaint
      _paths = List.from(_paths)..add(path);
      _redoStack.clear(); // Clear redo stack when new drawing starts
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final RenderBox? renderBox =
        _repaintBoundaryKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || _paths.isEmpty) return;

    final offset = renderBox.globalToLocal(details.globalPosition);
    setState(() {
      // Create a new list and new path object to trigger repaint
      final lastPath = _paths.last;
      final updatedPath = DrawingPath(
        points: List.from(lastPath.points)..add(offset),
        color: lastPath.color,
        strokeWidth: lastPath.strokeWidth,
        tool: lastPath.tool,
      );
      _paths = List.from(_paths)..removeLast()..add(updatedPath);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // Path is complete
  }

  void _undo() {
    if (_paths.isEmpty) return;
    setState(() {
      final lastPath = _paths.removeLast();
      _redoStack.add(lastPath);
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      final path = _redoStack.removeLast();
      _paths.add(path);
    });
  }

  Future<void> _saveAndSend() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Wait for the next frame to ensure everything is rendered
      await Future.delayed(const Duration(milliseconds: 100));

      // Capture the screenshot using RepaintBoundary
      final RenderRepaintBoundary? boundary =
          _repaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      
      if (boundary == null) {
        Navigator.of(context).pop(); // Close loading
        _showError('Failed to capture image');
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        Navigator.of(context).pop(); // Close loading
        _showError('Failed to encode image');
        return;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/edited_image_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      Navigator.of(context).pop(); // Close loading
      Navigator.of(context).pop(file); // Return edited file
    } catch (e) {
      Navigator.of(context).pop(); // Close loading
      _showError('Failed to save edited image: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

class DrawingPath {
  List<Offset> points;
  Color color;
  double strokeWidth;
  DrawingTool tool;

  DrawingPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.tool,
  });
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPath> paths;

  DrawingPainter(this.paths);

  @override
  void paint(Canvas canvas, Size size) {
    // Process paths in chronological order
    // Each eraser erases from paths drawn before it
    // Paths drawn after an eraser draw normally on top
    
    int lastEraserIndex = -1;
    
    // Find the index of the last eraser
    for (int i = paths.length - 1; i >= 0; i--) {
      if (paths[i].tool == DrawingTool.eraser && !paths[i].points.isEmpty) {
        lastEraserIndex = i;
        break;
      }
    }
    
    // If there are erasers, draw everything before the last eraser in a layer
    if (lastEraserIndex >= 0) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint(),
      );
      
      // Draw all paths up to and including the last eraser
      for (int i = 0; i <= lastEraserIndex; i++) {
        final path = paths[i];
        if (path.points.isEmpty) continue;
        
        final paint = Paint()
          ..color = path.color
          ..strokeWidth = path.strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        if (path.tool == DrawingTool.highlighter) {
          paint.blendMode = BlendMode.multiply;
        } else if (path.tool == DrawingTool.eraser) {
          paint.blendMode = BlendMode.clear;
          paint.color = Colors.black;
        }

        _drawPath(canvas, path, paint);
      }
      
      canvas.restore();
    }
    
    // Draw all paths after the last eraser directly on canvas
    // These can't be erased and draw normally
    for (int i = lastEraserIndex + 1; i < paths.length; i++) {
      final path = paths[i];
      if (path.points.isEmpty || path.tool == DrawingTool.eraser) continue;
      
      final paint = Paint()
        ..color = path.color
        ..strokeWidth = path.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (path.tool == DrawingTool.highlighter) {
        paint.blendMode = BlendMode.multiply;
      }

      _drawPath(canvas, path, paint);
    }
    
    // If there are no erasers, draw everything normally
    if (lastEraserIndex < 0) {
      for (final path in paths) {
        if (path.points.isEmpty) continue;
        
        final paint = Paint()
          ..color = path.color
          ..strokeWidth = path.strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        if (path.tool == DrawingTool.highlighter) {
          paint.blendMode = BlendMode.multiply;
        }

        _drawPath(canvas, path, paint);
      }
    }
  }

  void _drawPath(Canvas canvas, DrawingPath path, Paint paint) {
    if (path.points.isEmpty) return;
    
    if (path.points.length == 1) {
      // Draw a single point as a circle
      canvas.drawCircle(path.points[0], path.strokeWidth / 2, paint);
    } else {
      // Use smooth curves for continuous drawing (like WhatsApp)
      final pathToDraw = ui.Path();
      pathToDraw.moveTo(path.points[0].dx, path.points[0].dy);
      
      // Use quadratic bezier curves for smooth, continuous lines
      for (int i = 1; i < path.points.length; i++) {
        final currentPoint = path.points[i];
        final previousPoint = path.points[i - 1];
        
        if (i == 1) {
          // First segment: draw a line
          pathToDraw.lineTo(currentPoint.dx, currentPoint.dy);
        } else {
          // Use previous point as control point for smooth curve
          final controlPoint = previousPoint;
          pathToDraw.quadraticBezierTo(
            controlPoint.dx,
            controlPoint.dy,
            currentPoint.dx,
            currentPoint.dy,
          );
        }
      }
      
      canvas.drawPath(pathToDraw, paint);
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    // Always repaint if paths list changed
    if (oldDelegate.paths.length != paths.length) return true;
    
    // Check if any path has changed by comparing point counts
    // This ensures we repaint when points are added during drawing
    for (int i = 0; i < paths.length; i++) {
      if (oldDelegate.paths.length <= i) return true;
      final oldPath = oldDelegate.paths[i];
      final newPath = paths[i];
      
      // If point counts differ, definitely repaint
      if (oldPath.points.length != newPath.points.length) return true;
      
      // If it's a different object (new path created), repaint
      if (oldPath != newPath) return true;
    }
    
    return false;
  }
}

