import 'package:dart_quill_delta/dart_quill_delta.dart' as dq;
import 'package:fleather/fleather.dart' as fleather;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:logging/logging.dart';
import 'package:quill_html_converter/quill_html_converter.dart';

import '../../app/providers.dart';
import '../../data/providers.dart';

class TranscriptState {
  TranscriptState({
    required this.controller,
    required this.isSaving,
    this.errorMessage,
  });

  final fleather.FleatherController controller;
  final bool isSaving;
  final String? errorMessage;

  TranscriptState copyWith({
    fleather.FleatherController? controller,
    bool? isSaving,
    String? errorMessage,
  }) {
    return TranscriptState(
      controller: controller ?? this.controller,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
    );
  }
}

class TranscriptController extends StateNotifier<TranscriptState> {
  TranscriptController(this._ref)
      : super(
          TranscriptState(
            controller: fleather.FleatherController(
              document: fleather.ParchmentDocument(),
            ),
            isSaving: false,
          ),
        );

  final Ref _ref;
  // Auto-save removed
  String? _recordingId;
  late final Logger _logger = _ref.read(loggingServiceProvider).logger;

  Future<void> load(String recordingId) async {
    _recordingId = recordingId;
    final repo = _ref.read(transcriptRepositoryProvider);
    try {
      final html = await repo.fetchTranscript(recordingId);
      _logger.info(
        '[TranscriptController] load recording=$recordingId '
        'length=${html.length} preview=${html.replaceAll('\n', ' ').substring(0, html.length > 200 ? 200 : html.length)}',
      );
      if (html.trim().isEmpty) {
        state = state.copyWith(
          controller: fleather.FleatherController(
            document: fleather.ParchmentDocument(),
          ),
        );
        return;
      }
      final delta = _htmlToDelta(html);
      final document = fleather.ParchmentDocument.fromJson(delta.toJson());
      state = state.copyWith(
        controller: fleather.FleatherController(document: document),
      );
    } catch (error, stack) {
      _logger.severe('[TranscriptController] load failed', error, stack);
      state = state.copyWith(
        errorMessage: 'Failed to load transcript.',
      );
    }
  }

  Future<void> save() async {
    final recordingId = _recordingId;
    if (recordingId == null) return;
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final repo = _ref.read(transcriptRepositoryProvider);
      final parchmentDelta = state.controller.document.toDelta();
      final html = dq.Delta.fromJson(parchmentDelta.toJson()).toHtml();
      await repo.saveTranscript(recordingId: recordingId, html: html);
      state = state.copyWith(isSaving: false);
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> retranscribe() async {
    final recordingId = _recordingId;
    if (recordingId == null) return;
    final repo = _ref.read(transcriptRepositoryProvider);
    await repo.retranscribe(recordingId);
    await load(recordingId);
  }

  @override
  void dispose() {
    super.dispose();
  }

  dq.Delta _htmlToDelta(String html) {
    final document = html_parser.parse(html);
    final delta = dq.Delta();
    final body = document.body;
    if (body == null) {
      delta.insert('\n');
      return delta;
    }
    for (final node in body.nodes) {
      _convertNode(node, delta, const {});
    }
    _ensureTrailingNewline(delta);
    return delta;
  }

  void _ensureTrailingNewline(dq.Delta delta) {
    if (delta.isEmpty) {
      delta.insert('\n');
      return;
    }
    final last = delta.operations.last;
    final data = last.data;
    if (data is String && data.endsWith('\n')) return;
    delta.insert('\n');
  }

  void _convertNode(
    dom.Node node,
    dq.Delta delta,
    Map<String, dynamic> inlineAttrs, {
    Map<String, dynamic>? blockAttrs,
  }) {
    if (node is dom.Text) {
      final text = node.text;
      if (text.isEmpty) return;
      delta.insert(text, inlineAttrs.isEmpty ? null : inlineAttrs);
      return;
    }

    if (node is! dom.Element) return;

    final tag = node.localName ?? '';
    final mergedInline = _mergeInlineAttributes(inlineAttrs, _attrsForElement(node));
    final mergedBlock = _mergeBlockAttributes(blockAttrs, _blockAttrsForElement(tag));

    switch (tag) {
      case 'br':
        delta.insert('\n', mergedBlock);
        return;
      case 'p':
      case 'div':
        _convertChildren(node, delta, mergedInline, blockAttrs: blockAttrs);
        delta.insert('\n', mergedBlock);
        return;
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        _convertChildren(node, delta, mergedInline, blockAttrs: mergedBlock);
        delta.insert('\n', mergedBlock);
        return;
      case 'blockquote':
        _convertChildren(
          node,
          delta,
          mergedInline,
          blockAttrs: _mergeBlockAttributes(
            mergedBlock,
            fleather.ParchmentAttribute.bq.toJson(),
          ),
        );
        _ensureTrailingNewline(delta);
        return;
      case 'ul':
      case 'ol':
        final listAttrs = tag == 'ol'
            ? fleather.ParchmentAttribute.ol.toJson()
            : fleather.ParchmentAttribute.ul.toJson();
        for (final child in node.children) {
          if (child.localName != 'li') continue;
          _convertChildren(
            child,
            delta,
            mergedInline,
            blockAttrs: _mergeBlockAttributes(mergedBlock, listAttrs),
          );
          delta.insert('\n', _mergeBlockAttributes(mergedBlock, listAttrs));
        }
        return;
      case 'li':
        _convertChildren(node, delta, mergedInline, blockAttrs: mergedBlock);
        delta.insert('\n', mergedBlock);
        return;
      default:
        _convertChildren(node, delta, mergedInline, blockAttrs: mergedBlock);
    }
  }

  void _convertChildren(
    dom.Element element,
    dq.Delta delta,
    Map<String, dynamic> inlineAttrs, {
    Map<String, dynamic>? blockAttrs,
  }) {
    for (final child in element.nodes) {
      _convertNode(child, delta, inlineAttrs, blockAttrs: blockAttrs);
    }
  }

  Map<String, dynamic> _attrsForElement(dom.Element element) {
    final tag = element.localName ?? '';
    final attrs = <String, dynamic>{};

    switch (tag) {
      case 'strong':
      case 'b':
        attrs.addAll(fleather.ParchmentAttribute.bold.toJson());
        break;
      case 'em':
      case 'i':
        attrs.addAll(fleather.ParchmentAttribute.italic.toJson());
        break;
      case 'u':
        attrs.addAll(fleather.ParchmentAttribute.underline.toJson());
        break;
      case 's':
      case 'strike':
        attrs.addAll(fleather.ParchmentAttribute.strikethrough.toJson());
        break;
      case 'a':
        final href = element.attributes['href'];
        if (href != null && href.isNotEmpty) {
          attrs.addAll(fleather.ParchmentAttribute.link.fromString(href).toJson());
        }
        break;
      default:
        break;
    }

    final style = element.attributes['style'];
    if (style != null && style.trim().isNotEmpty) {
      attrs.addAll(_parseInlineStyle(style));
    }

    return attrs;
  }

  Map<String, dynamic> _blockAttrsForElement(String tag) {
    final attrs = <String, dynamic>{};
    switch (tag) {
      case 'h1':
        attrs.addAll(fleather.ParchmentAttribute.h1.toJson());
        break;
      case 'h2':
        attrs.addAll(fleather.ParchmentAttribute.h2.toJson());
        break;
      case 'h3':
        attrs.addAll(fleather.ParchmentAttribute.h3.toJson());
        break;
      case 'h4':
        attrs.addAll(fleather.ParchmentAttribute.h4.toJson());
        break;
      case 'h5':
        attrs.addAll(fleather.ParchmentAttribute.h5.toJson());
        break;
      case 'h6':
        attrs.addAll(fleather.ParchmentAttribute.h6.toJson());
        break;
      default:
        break;
    }
    return attrs;
  }

  Map<String, dynamic> _parseInlineStyle(String style) {
    final attrs = <String, dynamic>{};
    final parts = style.split(';');
    for (final part in parts) {
      final kv = part.split(':');
      if (kv.length != 2) continue;
      final key = kv[0].trim().toLowerCase();
      final value = kv[1].trim();
      if (value.isEmpty) continue;
      switch (key) {
        case 'color':
          final color = _parseCssColor(value);
          if (color != null) {
            attrs.addAll(
              fleather.ParchmentAttribute.foregroundColor.withColor(color).toJson(),
            );
          }
          break;
        case 'background-color':
          final color = _parseCssColor(value);
          if (color != null) {
            attrs.addAll(
              fleather.ParchmentAttribute.backgroundColor.withColor(color).toJson(),
            );
          }
          break;
        case 'font-weight':
          if (value == 'bold' || value == '700' || value == '600') {
            attrs.addAll(fleather.ParchmentAttribute.bold.toJson());
          }
          break;
        case 'font-style':
          if (value == 'italic') {
            attrs.addAll(fleather.ParchmentAttribute.italic.toJson());
          }
          break;
        case 'text-decoration':
          if (value.contains('underline')) {
            attrs.addAll(fleather.ParchmentAttribute.underline.toJson());
          }
          if (value.contains('line-through')) {
            attrs.addAll(fleather.ParchmentAttribute.strikethrough.toJson());
          }
          break;
        default:
          break;
      }
    }
    return attrs;
  }

  Map<String, dynamic> _mergeInlineAttributes(
    Map<String, dynamic> base,
    Map<String, dynamic> extra,
  ) {
    if (base.isEmpty) return extra;
    if (extra.isEmpty) return base;
    final merged = <String, dynamic>{}..addAll(base)..addAll(extra);
    return merged;
  }

  Map<String, dynamic>? _mergeBlockAttributes(
    Map<String, dynamic>? base,
    Map<String, dynamic>? extra,
  ) {
    if (base == null || base.isEmpty) return extra;
    if (extra == null || extra.isEmpty) return base;
    final merged = <String, dynamic>{}..addAll(base)..addAll(extra);
    return merged;
  }

  int? _parseCssColor(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('#')) {
      final hex = trimmed.substring(1);
      if (hex.length == 6) {
        return int.tryParse('FF$hex', radix: 16);
      }
      if (hex.length == 8) {
        return int.tryParse(hex, radix: 16);
      }
      if (hex.length == 3) {
        final r = hex[0] * 2;
        final g = hex[1] * 2;
        final b = hex[2] * 2;
        return int.tryParse('FF$r$g$b', radix: 16);
      }
      return null;
    }
    final rgbMatch = RegExp(r'rgba?\(([^)]+)\)').firstMatch(trimmed);
    if (rgbMatch != null) {
      final parts = rgbMatch.group(1)!.split(',').map((e) => e.trim()).toList();
      if (parts.length < 3) return null;
      final r = int.tryParse(parts[0]) ?? 0;
      final g = int.tryParse(parts[1]) ?? 0;
      final b = int.tryParse(parts[2]) ?? 0;
      var a = 255;
      if (parts.length >= 4) {
        final alpha = double.tryParse(parts[3]) ?? 1.0;
        a = (alpha.clamp(0.0, 1.0) * 255).round();
      }
      return (a << 24) | (r << 16) | (g << 8) | b;
    }
    return null;
  }
}

final transcriptControllerProvider =
    StateNotifierProvider<TranscriptController, TranscriptState>((ref) {
  return TranscriptController(ref);
});
