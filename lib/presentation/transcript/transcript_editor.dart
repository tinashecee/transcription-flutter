import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'transcript_controller.dart';
import '../../data/providers.dart';
import '../recordings/recordings_controller.dart';

class TranscriptEditor extends ConsumerStatefulWidget {
  const TranscriptEditor({
    super.key,
    required this.recordingId,
    this.isAssigned = true,
    this.isEditing = false,
  });

  final String recordingId;
  final bool isAssigned;
  final bool isEditing;

  @override
  ConsumerState<TranscriptEditor> createState() => _TranscriptEditorState();
}

class _TranscriptEditorState extends ConsumerState<TranscriptEditor> {
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  // State for visual zoom
  double _zoomLevel = 1.0; 

  // Font options
  final Map<String, TextStyle> _fontMap = {
      'Calibri': GoogleFonts.openSans(),
      'Aptos': GoogleFonts.inter(),
      'Arial': GoogleFonts.arimo(),
      'Times New Roman': GoogleFonts.tinos(),
      'Helvetica': GoogleFonts.roboto(),
      'Verdana': GoogleFonts.sourceSans3(),
      'Georgia': GoogleFonts.lora(),
      'Cambria': GoogleFonts.caladea(),
      'Trebuchet MS': GoogleFonts.firaSans(),
      'Courier New': GoogleFonts.courierPrime(),
      'Comic Sans MS': GoogleFonts.comicNeue(),
      'Garamond': GoogleFonts.ebGaramond(),
      'Century Gothic': GoogleFonts.questrial(),
      'Tahoma': GoogleFonts.openSans(),
      'Segoe UI': GoogleFonts.notoSans(),
  };

  @override
  void initState() {
    super.initState();
    // Load transcript
    ref.read(transcriptControllerProvider.notifier).load(widget.recordingId);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transcriptControllerProvider);
    final controller = state.controller;
    final canEdit = widget.isAssigned && widget.isEditing;
    controller.readOnly = !canEdit;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.errorMessage != null)
              _buildErrorBanner(state.errorMessage!)
            else ...[
              
              // Custom Toolbar
              if (canEdit)
                _buildToolbar(controller),

              // Editor Surface
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (!canEdit && !widget.isAssigned)
                         _buildReadOnlyBanner(),

                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: QuillEditor.basic(
                            controller: controller,
                            focusNode: _focusNode,
                            scrollController: _scrollController,
                            config: QuillEditorConfig(
                              scrollable: true,
                              autoFocus: false,
                              expands: false,
                              padding: const EdgeInsets.all(20),
                              showCursor: canEdit,
                              customStyles: DefaultStyles(
                                paragraph: DefaultTextBlockStyle(
                                  TextStyle(
                                    fontSize: 14 * _zoomLevel,
                                    color: const Color(0xFF374151),
                                    height: 1.15, // Revert to standard comfortable height
                                    fontFamily: 'Inter',
                                  ),
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(6, 0), // Add top spacing for paragraphs
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),

        // Saving Indicator
        if (state.isSaving)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Saving...',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Text(message, style: TextStyle(color: Colors.red.shade900)),
          const Spacer(),
          TextButton(
            onPressed: () => ref.read(transcriptControllerProvider.notifier).load(widget.recordingId),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            'Read-only view',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(QuillController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Basic Formatting
                _buildIconButton(
                  Icons.format_bold, 
                  () => _toggleAttribute(controller, Attribute.bold),
                  isActive: _isAttributeActive(controller, Attribute.bold),
                  tooltip: 'Bold',
                ),
                _buildIconButton(
                  Icons.format_italic, 
                  () => _toggleAttribute(controller, Attribute.italic),
                  isActive: _isAttributeActive(controller, Attribute.italic),
                  tooltip: 'Italic',
                ),
                _buildIconButton(
                  Icons.format_underline, 
                  () => _toggleAttribute(controller, Attribute.underline),
                  isActive: _isAttributeActive(controller, Attribute.underline),
                  tooltip: 'Underline',
                ),
                _buildDivider(),
                
                // Alignment
                _buildIconButton(
                  Icons.format_align_left, 
                  () => _applyAttribute(controller, Attribute.leftAlignment),
                  isActive: _isAttributeActive(controller, Attribute.leftAlignment) || 
                            (!_isAttributeActive(controller, Attribute.centerAlignment) && 
                             !_isAttributeActive(controller, Attribute.rightAlignment) && 
                             !_isAttributeActive(controller, Attribute.justifyAlignment)),
                  tooltip: 'Align Left',
                ),
                _buildIconButton(
                  Icons.format_align_center, 
                  () => _applyAttribute(controller, Attribute.centerAlignment),
                  isActive: _isAttributeActive(controller, Attribute.centerAlignment),
                  tooltip: 'Align Center',
                ),
                _buildIconButton(
                  Icons.format_align_right, 
                  () => _applyAttribute(controller, Attribute.rightAlignment),
                  isActive: _isAttributeActive(controller, Attribute.rightAlignment),
                  tooltip: 'Align Right',
                ),
                _buildIconButton(
                  Icons.format_align_justify, 
                  () => _applyAttribute(controller, Attribute.justifyAlignment),
                  isActive: _isAttributeActive(controller, Attribute.justifyAlignment),
                  tooltip: 'Justify',
                ),
                _buildDivider(),

                // Lists
                _buildIconButton(
                  Icons.format_list_bulleted, 
                  () => _toggleAttribute(controller, Attribute.ul),
                  isActive: _isAttributeActive(controller, Attribute.ul),
                  tooltip: 'Bulleted List',
                ),
                _buildIconButton(
                  Icons.format_list_numbered, 
                  () => _toggleAttribute(controller, Attribute.ol),
                  isActive: _isAttributeActive(controller, Attribute.ol),
                  tooltip: 'Numbered List',
                ),
                _buildDivider(),
                
                // Colors
                _buildColorButton(controller, false), // Text Color
                _buildColorButton(controller, true), // Highlight Color
                _buildDivider(),

                // Font Family
                _buildFontFamilySelector(controller),
                const SizedBox(width: 4),

                // Font Size
                _buildFontSizeSelector(controller),
                const SizedBox(width: 4),

                // Line Spacing
                _buildLineHeightSelector(controller),
                _buildDivider(),

                 // Zoom
                 _buildIconButton(Icons.zoom_out, () {
                   setState(() {
                     _zoomLevel = (_zoomLevel - 0.1).clamp(0.5, 3.0);
                   });
                 }, tooltip: 'Zoom Out'),
                 Text('${(_zoomLevel * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                 _buildIconButton(Icons.zoom_in, () {
                   setState(() {
                     _zoomLevel = (_zoomLevel + 0.1).clamp(0.5, 3.0);
                   });
                 }, tooltip: 'Zoom In'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorButton(QuillController controller, bool isBackground) {
    final styles = controller.getSelectionStyle();
    final attributeKey = isBackground ? 'background' : 'color';
    final colorHex = styles.attributes[attributeKey]?.value;
    
    Color? activeColor;
    if (colorHex != null && colorHex is String) {
       // Hex string comes as '#RRGGBB' usually
       if (colorHex.startsWith('#')) {
          activeColor = Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
       }
    }

    return Tooltip(
      message: isBackground ? 'Highlight Color' : 'Text Color',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(isBackground ? 'Highlight Color' : 'Text Color'),
                content: SingleChildScrollView(
                  child: BlockPicker(
                    pickerColor: activeColor ?? Colors.black,
                    onColorChanged: (color) {
                      final hex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
                      if (isBackground) {
                        controller.formatSelection(BackgroundAttribute(hex));
                      } else {
                        controller.formatSelection(ColorAttribute(hex));
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              isBackground ? Icons.format_color_fill : Icons.format_color_text,
              size: 20,
              color: activeColor ?? Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFontFamilySelector(QuillController controller) {
    // Enable reactivity
    final styles = controller.getSelectionStyle();
    final currentFont = styles.attributes['font']?.value as String? ?? 'Aptos'; // Default to Aptos if null

    return PopupMenuButton<String>(
      tooltip: 'Font Family',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
             // Constrain width to avoid jumping
             ConstrainedBox(
               constraints: const BoxConstraints(maxWidth: 100),
               child: Text(
                 currentFont, 
                 style: const TextStyle(fontSize: 12),
                 overflow: TextOverflow.ellipsis,
               )
             ),
             const SizedBox(width: 4),
             const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) {
         return _fontMap.keys.map((fontName) {
           return PopupMenuItem<String>(
             value: fontName,
             child: Text(fontName, style: _fontMap[fontName]),
             onTap: () {
               controller.formatSelection(Attribute.fromKeyValue('font', fontName));
             },
           );
         }).toList();
      },
    );
  }

  Widget _buildFontSizeSelector(QuillController controller) {
      final styles = controller.getSelectionStyle();
      // Size attribute in Quill is often String or Double depending... 
      // Default styles usually don't set size unless explicit. 
      // Let's assume default is 14 if missing.
      final currentSizeVal = styles.attributes['size']?.value;
      String currentSize = '14';
      if (currentSizeVal != null) {
        currentSize = currentSizeVal.toString();
        // Maybe truncate if it's a double like 14.0 -> 14
        if (currentSize.endsWith('.0')) {
          currentSize = currentSize.substring(0, currentSize.length - 2);
        }
      }

      return PopupMenuButton<double>(
      tooltip: 'Font Size',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
             Text(currentSize, style: const TextStyle(fontSize: 12)),
             const SizedBox(width: 4),
             const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) {
         return [10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 24.0, 30.0].map((size) {
           return PopupMenuItem<double>(
             value: size,
             child: Text(size.toStringAsFixed(0)),
             onTap: () {
               controller.formatSelection(Attribute.fromKeyValue('size', size));
             },
           );
         }).toList();
      },
    );
  }

  Widget _buildLineHeightSelector(QuillController controller) {
    final styles = controller.getSelectionStyle();
    final currentHeightVal = styles.attributes['line-height']?.value;
    String currentHeight = '1.15'; // Default (Standard)
    
    // Check for block attribute in styles? 
    // Usually getSelectionStyle merges block attributes too.
    for(final attr in styles.attributes.values) {
        if (attr.key == Attribute.lineHeight.key) {
           currentHeight = attr.value.toString();
           break;
        }
    }

    return PopupMenuButton<double>(
      tooltip: 'Line Spacing',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
             const Icon(Icons.format_line_spacing, size: 16),
             const SizedBox(width: 4),
             Text(currentHeight, style: const TextStyle(fontSize: 12)),
             const SizedBox(width: 4),
             const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) {
         return [1.0, 1.15, 1.5, 2.0].map((height) {
           return PopupMenuItem<double>(
             value: height,
             child: Text(height.toString()),
             onTap: () {
               // Apply line height as a block attribute
               controller.formatSelection(Attribute.clone(Attribute.lineHeight, height));
             },
           );
         }).toList();
      },
    );
  }

  bool _isAttributeActive(QuillController controller, Attribute attribute) {
    final style = controller.getSelectionStyle();
    return style.attributes.containsKey(attribute.key) && 
           style.attributes[attribute.key]!.value == attribute.value;
  }

  void _toggleAttribute(QuillController controller, Attribute attribute) {
    final isActive = _isAttributeActive(controller, attribute);
    if (isActive) {
      controller.formatSelection(Attribute.clone(attribute, null));
    } else {
      controller.formatSelection(attribute);
    }
  }

  void _applyAttribute(QuillController controller, Attribute attribute) {
    controller.formatSelection(attribute);
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.grey.shade300,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed, {bool isActive = false, String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: isActive ? Colors.blue.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              size: 20,
              color: isActive ? Colors.blue.shade700 : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}
