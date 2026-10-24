import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'common.dart';

class BookCard extends StatefulWidget {
  final Book book;
  final VoidCallback onDownloaded;
  const BookCard({super.key, required this.book, required this.onDownloaded});

  @override
  State<BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<BookCard> {
  double? _progress;

  Future<void> _download() async {
    final book = widget.book;
    if (!book.canDownload) {
      _showLegalNotice();
      return;
    }
    try {
      setState(() => _progress = 0);
      final dir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${dir.path}/books');
      if (!await booksDir.exists()) await booksDir.create(recursive: true);

      final safeTitle = book.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final path = '${booksDir.path}/$safeTitle.${book.ext}';

      await Dio().download(
        book.downloadUrl!,
        path,
        onReceiveProgress: (rec, total) {
          if (total > 0 && mounted) setState(() => _progress = rec / total);
        },
      );
      if (!mounted) return;
      setState(() => _progress = null);
      widget.onDownloaded();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: const Text('تم التحميل، تجده في مكتبتي'),
        action: SnackBarAction(
            label: 'فتح', onPressed: () => OpenFilex.open(path)),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _progress = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('فشل التحميل، حاول مرة أخرى')));
    }
  }

  void _showLegalNotice() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.info_outline, size: 36, color: kAccent),
        title: const Text('هذا الكتاب غير متاح للتحميل المجاني',
            textAlign: TextAlign.center),
        content: const SingleChildScrollView(
          child: Text(
            'هذا الكتاب محمي بحقوق النشر أو لا تتوفر له نسخة مجانية مرخّصة، '
            'لذلك لا يمكننا تحميله من داخل التطبيق.\n\n'
            'يمكنك الحصول عليه بطرق قانونية، مثل:\n'
            '• شراؤه من المتاجر الإلكترونية الرسمية أو من موقع الناشر.\n'
            '• استعارته من مكتبة عامة أو جامعية، فكثير منها يوفّر الإعارة الرقمية.\n'
            '• البحث عن نسخة مرخّصة بشكل مفتوح، أو مراسلة الناشر أو المؤلف.\n\n'
            'وبذلك تدعم المؤلفين وتحافظ على حقوقهم.',
            style: TextStyle(height: 1.7),
          ),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                book.coverUrl != null
                    ? Image.network(
                        book.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const CoverPlaceholder(),
                        loadingBuilder: (c, child, p) =>
                            p == null ? child : const CoverPlaceholder(),
                      )
                    : const CoverPlaceholder(),
                if (!book.canDownload)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('محمي',
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.3)),
                const SizedBox(height: 2),
                Text(book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        color: scheme.onSurface.withOpacity(0.6))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: _progress != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                        value: _progress, minHeight: 36),
                  )
                : SizedBox(
                    height: 36,
                    child: book.canDownload
                        ? FilledButton.icon(
                            onPressed: _download,
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('تحميل'),
                          )
                        : OutlinedButton.icon(
                            onPressed: _download,
                            icon: const Icon(Icons.info_outline, size: 18),
                            label: const Text('غير متاح'),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class CoverPlaceholder extends StatelessWidget {
  const CoverPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [kPrimary.withOpacity(0.85), kPrimaryDark],
        ),
      ),
      child: const Center(
          child: Icon(Icons.menu_book_rounded, color: Colors.white70, size: 44)),
    );
  }
}
