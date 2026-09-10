import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Turns WhatsApp's inline formatting into rendered spans.
///
/// WhatsApp marks up text with single characters — `*bold*`, `_italic_`,
/// `~strike~`, `` `mono` `` and ```` ```blocks``` ```` — and its own clients
/// render them. Ours showed the markers verbatim, so every formatted message,
/// whether written by an agent, a customer or the AI assistant, arrived littered
/// with asterisks and underscores.
///
/// Unmatched markers are left as literal characters, which is what WhatsApp
/// does: "2 * 3 * 4" is arithmetic, not emphasis.
class WhatsappText {
  /// Opening marker must not sit inside a word and must be followed by
  /// non-space; the closing marker must be preceded by non-space and likewise
  /// not run into a word. That is what stops `snake_case_name` becoming italic.
  static final _patterns = <String, RegExp>{
    'bold': RegExp(r'(?<![\w*])\*(?=\S)(.+?)(?<=\S)\*(?![\w*])', dotAll: true),
    'italic': RegExp(r'(?<![\w_])_(?=\S)(.+?)(?<=\S)_(?![\w_])', dotAll: true),
    'strike': RegExp(r'(?<![\w~])~(?=\S)(.+?)(?<=\S)~(?![\w~])', dotAll: true),
  };

  /// Fenced and inline code, handled before everything else so their contents
  /// are never treated as emphasis.
  static final _codeBlock = RegExp(r'```(?:\w+\n)?(.+?)```', dotAll: true);
  static final _inlineCode = RegExp(r'`(?=\S)(.+?)(?<=\S)`');

  static final _url = RegExp(
    r'(?:https?://|www\.)[^\s<>()"' r"']+",
    caseSensitive: false,
  );

  /// Builds the spans for [text] under [base].
  ///
  /// [onLinkTap] overrides the default behaviour of opening the URL
  /// externally — useful where a screen wants to confirm first.
  static List<InlineSpan> spans(
    String text, {
    required TextStyle base,
    Color? linkColor,
    void Function(String url)? onLinkTap,
  }) {
    return _parse(
      text,
      base,
      linkColor ?? base.color ?? const Color(0xFF1B74E4),
      onLinkTap,
    );
  }

  /// The text with its formatting markers removed.
  ///
  /// For places that show a one-line preview — chat list rows, notification
  /// bodies — where the markers are noise but the styling cannot be rendered.
  static String plain(String? text) {
    if (text == null || text.isEmpty) return '';

    var out = text;

    out = out.replaceAllMapped(_codeBlock, (m) => m.group(1) ?? '');
    out = out.replaceAllMapped(_inlineCode, (m) => m.group(1) ?? '');

    // Repeated until stable so nested markers unwrap fully.
    for (var i = 0; i < 3; i++) {
      final before = out;

      for (final pattern in _patterns.values) {
        out = out.replaceAllMapped(pattern, (m) => m.group(1) ?? '');
      }

      if (out == before) break;
    }

    return out;
  }

  static List<InlineSpan> _parse(
    String text,
    TextStyle style,
    Color linkColor,
    void Function(String url)? onLinkTap,
  ) {
    if (text.isEmpty) return const [];

    // Code first: whatever is inside must survive untouched.
    final code = _firstMatch(text, [_codeBlock, _inlineCode]);

    if (code != null) {
      return _split(
        text,
        code.match,
        style,
        linkColor,
        onLinkTap,
        (inner) => [
          TextSpan(
            text: inner,
            style: style.copyWith(
              fontFamily: 'monospace',
              fontFamilyFallback: const ['Menlo', 'Courier New'],
            ),
          ),
        ],
      );
    }

    final emphasis = _firstMatch(text, _patterns.values.toList());

    if (emphasis != null) {
      final kind = _patterns.entries
          .firstWhere((e) => e.value == emphasis.pattern)
          .key;

      final styled = switch (kind) {
        'bold' => style.copyWith(fontWeight: FontWeight.w700),
        'italic' => style.copyWith(fontStyle: FontStyle.italic),
        _ => style.copyWith(decoration: TextDecoration.lineThrough),
      };

      return _split(
        text,
        emphasis.match,
        style,
        linkColor,
        onLinkTap,
        // Recurse so `*bold with _italic_ inside*` renders as both.
        (inner) => _parse(inner, styled, linkColor, onLinkTap),
      );
    }

    return _linkify(text, style, linkColor, onLinkTap);
  }

  /// Rebuilds `before + rendered(inner) + after`, recursing on the outer parts.
  static List<InlineSpan> _split(
    String text,
    RegExpMatch match,
    TextStyle style,
    Color linkColor,
    void Function(String url)? onLinkTap,
    List<InlineSpan> Function(String inner) render,
  ) {
    return [
      ..._parse(text.substring(0, match.start), style, linkColor, onLinkTap),
      ...render(match.group(1) ?? ''),
      ..._parse(text.substring(match.end), style, linkColor, onLinkTap),
    ];
  }

  /// The earliest match across [patterns], so nesting resolves outside-in.
  static ({RegExpMatch match, RegExp pattern})? _firstMatch(
    String text,
    List<RegExp> patterns,
  ) {
    RegExpMatch? best;
    RegExp? bestPattern;

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);

      if (match is RegExpMatch && (best == null || match.start < best.start)) {
        best = match;
        bestPattern = pattern;
      }
    }

    return best == null ? null : (match: best, pattern: bestPattern!);
  }

  static List<InlineSpan> _linkify(
    String text,
    TextStyle style,
    Color linkColor,
    void Function(String url)? onLinkTap,
  ) {
    if (text.isEmpty) return const [];

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in _url.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start), style: style));
      }

      final raw = match.group(0)!;
      // Trailing punctuation belongs to the sentence, not the URL.
      final trimmed = raw.replaceFirst(RegExp(r'[.,;:!?]+$'), '');
      final href = trimmed.startsWith('www.') ? 'https://$trimmed' : trimmed;

      spans.add(TextSpan(
        text: trimmed,
        style: style.copyWith(
          color: linkColor,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            if (onLinkTap != null) {
              onLinkTap(href);

              return;
            }

            launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
          },
      ));

      if (trimmed.length < raw.length) {
        spans.add(TextSpan(text: raw.substring(trimmed.length), style: style));
      }

      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: style));
    }

    return spans;
  }
}
