import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/models/message_model.dart';
import 'package:cookrange/core/widgets/ds/chat/app_message_bubble.dart';

/// Faz 2 §2.2 — `buildMentionSpans` is the pure function (no Firebase, no
/// widget tree) behind `AppMessageBubble`'s @mention highlighting. CLAUDE.md
/// §8: "New pure logic gets a unit test... has no excuse" — this is exactly
/// that class of function, so it's public (not `_`-private) specifically to
/// make this file possible.
void main() {
  const base = TextStyle(color: Colors.black, fontSize: 15);
  const mentionColor = Colors.blue;

  /// Flattens a TextSpan tree back to plain text, for asserting the full
  /// reconstructed string still equals the original body exactly.
  String flatten(TextSpan span) {
    if (span.children == null) return span.text ?? '';
    return span.children!.map((c) => c is TextSpan ? flatten(c) : '').join();
  }

  group('buildMentionSpans', () {
    test('no mentions returns a single plain span with the base style', () {
      final span = buildMentionSpans(
        body: 'hello world',
        mentions: const [],
        baseStyle: base,
        mentionColor: mentionColor,
      );
      expect(span.text, 'hello world');
      expect(span.children, isNull);
      expect(span.style, base);
    });

    test(
        'a single mention is split into before/mention/after with correct styling',
        () {
      const body = 'hey @Ali how are you';
      const mention = MessageMention(uid: 'u1', offset: 4, len: 4); // "@Ali"
      final span = buildMentionSpans(
        body: body,
        mentions: [mention],
        baseStyle: base,
        mentionColor: mentionColor,
      );

      expect(flatten(span), body);
      expect(span.children, isNotNull);
      final children = span.children!.cast<TextSpan>();
      expect(children.map((c) => c.text), ['hey ', '@Ali', ' how are you']);
      expect(children[1].style?.color, mentionColor);
      expect(children[1].style?.fontWeight, FontWeight.w700);
      expect(children[0].style?.color, base.color);
    });

    test(
        'multiple mentions render in order, non-mention text preserved between them',
        () {
      const body = '@Ali and @Veli are here';
      const mentions = [
        MessageMention(uid: 'u1', offset: 0, len: 4), // "@Ali"
        MessageMention(uid: 'u2', offset: 9, len: 5), // "@Veli"
      ];
      final span = buildMentionSpans(
        body: body,
        mentions: mentions,
        baseStyle: base,
        mentionColor: mentionColor,
      );

      expect(flatten(span), body);
      final children = span.children!.cast<TextSpan>();
      expect(
          children.map((c) => c.text), ['@Ali', ' and ', '@Veli', ' are here']);
    });

    test(
        'a mention whose span no longer fits inside body (stale offset) is skipped, not thrown',
        () {
      const body = 'short';
      const mention =
          MessageMention(uid: 'u1', offset: 10, len: 5); // out of range
      final span = buildMentionSpans(
        body: body,
        mentions: [mention],
        baseStyle: base,
        mentionColor: mentionColor,
      );
      // Falls back to a plain, unsplit span since the only mention was invalid.
      expect(flatten(span), body);
    });

    test('a negative offset or zero/negative length is defensively skipped',
        () {
      const body = 'hello world';
      const mentions = [
        MessageMention(uid: 'u1', offset: -1, len: 3),
        MessageMention(uid: 'u2', offset: 2, len: 0),
      ];
      final span = buildMentionSpans(
        body: body,
        mentions: mentions,
        baseStyle: base,
        mentionColor: mentionColor,
      );
      expect(flatten(span), body);
    });

    test('overlapping mentions: the second (out-of-order-start) one is skipped',
        () {
      const body = '@AliVeli text';
      const mentions = [
        MessageMention(uid: 'u1', offset: 0, len: 7), // "@AliVel"
        MessageMention(uid: 'u2', offset: 3, len: 4), // overlaps the first
      ];
      final span = buildMentionSpans(
        body: body,
        mentions: mentions,
        baseStyle: base,
        mentionColor: mentionColor,
      );
      expect(flatten(span), body);
      final children = span.children!.cast<TextSpan>();
      // Only the first mention's span should be tinted; the overlap is
      // absorbed into the following plain-text remainder.
      expect(children.first.style?.color, mentionColor);
      expect(children.first.text, '@AliVel');
    });
  });
}
