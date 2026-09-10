import 'package:flutter/widgets.dart';

/// Direction a piece of user-written text should be laid out in.
///
/// Uses the Unicode "first strong character" rule: the paragraph takes the
/// direction of the first character that has one, ignoring digits, punctuation
/// and whitespace. That is what WhatsApp does, and it is why an Arabic message
/// starting with a Latin product name still reads right-to-left once the Arabic
/// begins — the first *strong* character is what decides.
///
/// Message bubbles otherwise inherit the app's own directionality, so Arabic
/// arrived left-aligned with its punctuation stranded on the wrong side.
TextDirection directionOf(String? text) {
  if (text == null || text.isEmpty) return TextDirection.ltr;

  for (final rune in text.runes) {
    if (_isStrongRtl(rune)) return TextDirection.rtl;
    if (_isStrongLtr(rune)) return TextDirection.ltr;
  }

  return TextDirection.ltr;
}

/// True when [text] should be laid out right-to-left.
bool isRtlText(String? text) => directionOf(text) == TextDirection.rtl;

/// Hebrew, Arabic, Syriac, Thaana, N'Ko and Samaritan, plus the Arabic
/// presentation-form blocks that Office documents and some keyboards emit.
bool _isStrongRtl(int rune) =>
    (rune >= 0x0590 && rune <= 0x05FF) || // Hebrew
    (rune >= 0x0600 && rune <= 0x06FF) || // Arabic
    (rune >= 0x0700 && rune <= 0x074F) || // Syriac
    (rune >= 0x0750 && rune <= 0x077F) || // Arabic Supplement
    (rune >= 0x0780 && rune <= 0x07BF) || // Thaana
    (rune >= 0x07C0 && rune <= 0x07FF) || // N'Ko
    (rune >= 0x0800 && rune <= 0x083F) || // Samaritan
    (rune >= 0x08A0 && rune <= 0x08FF) || // Arabic Extended-A
    (rune >= 0xFB1D && rune <= 0xFDFF) || // Hebrew/Arabic presentation forms
    (rune >= 0xFE70 && rune <= 0xFEFF); // Arabic presentation forms-B

/// Latin, Greek and Cyrillic. Digits and punctuation are deliberately excluded:
/// they are direction-neutral, so "2024 مرحبا" is still an Arabic paragraph.
bool _isStrongLtr(int rune) =>
    (rune >= 0x0041 && rune <= 0x005A) || // A-Z
    (rune >= 0x0061 && rune <= 0x007A) || // a-z
    (rune >= 0x00C0 && rune <= 0x02B8) || // Latin supplements + extensions
    (rune >= 0x0370 && rune <= 0x03FF) || // Greek
    (rune >= 0x0400 && rune <= 0x04FF); // Cyrillic
