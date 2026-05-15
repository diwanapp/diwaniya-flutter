import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.surface,
        appBar: AppBar(
          backgroundColor: c.surface,
          elevation: 0,
          centerTitle: true,
          title: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          iconTheme: IconThemeData(color: c.onSurface),
        ),
        body: FutureBuilder<String>(
          future: rootBundle.loadString(assetPath),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: CircularProgressIndicator(color: c.primary),
              );
            }

            if (snapshot.hasError) {
              return _ErrorState(
                message: 'تعذر تحميل المستند. يرجى المحاولة لاحقًا.',
              );
            }

            final raw = snapshot.data ?? '';
            final blocks = _LegalMarkdownParser.parse(raw);

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 36),
              itemCount: blocks.length,
              itemBuilder: (context, index) {
                return _LegalBlockView(block: blocks[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

enum _LegalBlockType { h1, h2, h3, bullet, numbered, paragraph, divider }

class _LegalBlock {
  const _LegalBlock(this.type, this.text);

  final _LegalBlockType type;
  final String text;
}

class _LegalMarkdownParser {
  static List<_LegalBlock> parse(String input) {
    final lines =
        input.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final blocks = <_LegalBlock>[];
    final paragraph = <String>[];

    void flushParagraph() {
      final text = paragraph.join(' ').trim();
      paragraph.clear();
      if (text.isNotEmpty) {
        blocks.add(_LegalBlock(_LegalBlockType.paragraph, _cleanInline(text)));
      }
    }

    for (final original in lines) {
      var line = _unescapeMarkdown(original).trim();

      if (line.isEmpty) {
        flushParagraph();
        continue;
      }

      if (_isDivider(line)) {
        flushParagraph();
        blocks.add(const _LegalBlock(_LegalBlockType.divider, ''));
        continue;
      }

      if (line.startsWith('### ')) {
        flushParagraph();
        blocks.add(
            _LegalBlock(_LegalBlockType.h3, _cleanInline(line.substring(4))));
        continue;
      }

      if (line.startsWith('## ')) {
        flushParagraph();
        blocks.add(
            _LegalBlock(_LegalBlockType.h2, _cleanInline(line.substring(3))));
        continue;
      }

      if (line.startsWith('# ')) {
        flushParagraph();
        blocks.add(
            _LegalBlock(_LegalBlockType.h1, _cleanInline(line.substring(2))));
        continue;
      }

      if (line.startsWith('- ') || line.startsWith('* ')) {
        flushParagraph();
        blocks.add(_LegalBlock(
            _LegalBlockType.bullet, _cleanInline(line.substring(2))));
        continue;
      }

      final numbered = _numberedText(line);
      if (numbered != null) {
        flushParagraph();
        blocks
            .add(_LegalBlock(_LegalBlockType.numbered, _cleanInline(numbered)));
        continue;
      }

      paragraph.add(line);
    }

    flushParagraph();
    return blocks;
  }

  static String _unescapeMarkdown(String value) {
    return value
        .replaceAll(r'\#', '#')
        .replaceAll(r'\*', '*')
        .replaceAll(r'\-', '-')
        .replaceAll(r'\_', '_')
        .replaceAll(r'\[', '[')
        .replaceAll(r'\]', ']')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\|', '|')
        .replaceAll(r'\!', '!');
  }

  static bool _isDivider(String line) {
    final compact = line.replaceAll(' ', '');
    return compact == '---' || compact == '***' || compact == '___';
  }

  static String? _numberedText(String line) {
    if (line.length < 3) return null;
    var i = 0;
    while (i < line.length) {
      final code = line.codeUnitAt(i);
      if (code < 48 || code > 57) break;
      i++;
    }
    if (i == 0 || i >= line.length) return null;
    if (line[i] != '.') return null;
    final afterDot = i + 1;
    if (afterDot >= line.length || line[afterDot] != ' ') return null;
    return line.substring(afterDot + 1);
  }

  static String _cleanInline(String value) {
    var text = value.trim();

    // Keep emails and websites readable while removing common Markdown syntax.
    text = text.replaceAll('**', '');
    text = text.replaceAll('__', '');
    text = text.replaceAll('`', '');

    // Convert simple Markdown links: [label](url) -> label / url
    text = _flattenMarkdownLinks(text);

    // Clean leftover table pipes if a pasted line contained them.
    text = text.replaceAll('|', ' ');

    while (text.contains('  ')) {
      text = text.replaceAll('  ', ' ');
    }

    return text.trim();
  }

  static String _flattenMarkdownLinks(String input) {
    var text = input;
    while (true) {
      final openLabel = text.indexOf('[');
      if (openLabel < 0) return text;
      final closeLabel = text.indexOf(']', openLabel + 1);
      if (closeLabel < 0 ||
          closeLabel + 1 >= text.length ||
          text[closeLabel + 1] != '(') {
        return text;
      }
      final closeUrl = text.indexOf(')', closeLabel + 2);
      if (closeUrl < 0) return text;

      final label = text.substring(openLabel + 1, closeLabel).trim();
      final url = text.substring(closeLabel + 2, closeUrl).trim();
      final replacement = url.isEmpty || label == url ? label : '$label ($url)';
      text = text.substring(0, openLabel) +
          replacement +
          text.substring(closeUrl + 1);
    }
  }
}

class _LegalBlockView extends StatelessWidget {
  const _LegalBlockView({required this.block});

  final _LegalBlock block;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    switch (block.type) {
      case _LegalBlockType.h1:
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 18),
          child: Text(
            block.text,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: c.onSurface,
              fontSize: 22,
              height: 1.55,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      case _LegalBlockType.h2:
        return Padding(
          padding: const EdgeInsets.only(top: 26, bottom: 12),
          child: Text(
            block.text,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: c.onSurface,
              fontSize: 20,
              height: 1.55,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      case _LegalBlockType.h3:
        return Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(
            block.text,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: c.onSurface,
              fontSize: 17,
              height: 1.55,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      case _LegalBlockType.bullet:
        return _IndentedLine(marker: '•', text: block.text);
      case _LegalBlockType.numbered:
        return _IndentedLine(marker: '–', text: block.text);
      case _LegalBlockType.divider:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Divider(
              color: c.outlineVariant.withValues(alpha: 0.55), height: 1),
        );
      case _LegalBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            block.text,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: c.onSurfaceVariant,
              fontSize: 16,
              height: 1.9,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
    }
  }
}

class _IndentedLine extends StatelessWidget {
  const _IndentedLine({required this.marker, required this.text});

  final String marker;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: TextDirection.rtl,
        children: [
          Text(
            marker,
            style: TextStyle(
              color: c.primary,
              fontSize: 17,
              height: 1.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: c.onSurfaceVariant,
                fontSize: 16,
                height: 1.85,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.error,
            fontSize: 16,
            height: 1.7,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
