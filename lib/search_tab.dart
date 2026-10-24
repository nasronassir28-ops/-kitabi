import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'book_card.dart';
import 'common.dart';

class SearchTab extends StatefulWidget {
  final VoidCallback onDownloaded;
  const SearchTab({super.key, required this.onDownloaded});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _controller = TextEditingController();
  List<Book> _books = [];
  bool _loading = true;
  String? _error;
  String _sectionTitle = 'الأكثر تحميلاً';

  static const _suggestions = [
    'Shakespeare',
    'Dickens',
    'Jane Austen',
    'Mark Twain',
    'Tolstoy',
    'Poetry',
  ];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch([String q = '']) async {
    setState(() {
      _loading = true;
      _error = null;
      _sectionTitle = q.isEmpty ? 'الأكثر تحميلاً' : 'نتائج «$q»';
    });
    try {
      final uri = Uri.https(
          'gutendex.com', '/books', q.isEmpty ? null : {'search': q});
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw Exception('status ${res.statusCode}');
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      setState(() {
        _books = (data['results'] as List)
            .map((e) => Book.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } catch (_) {
      setState(() => _error = 'تعذّر الاتصال. تحقق من الإنترنت وحاول مجدداً.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submit([String? text]) {
    if (text != null) _controller.text = text;
    FocusScope.of(context).unfocus();
    _fetch(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: GradientHeader(
            subtitle: 'مكتبتك المجانية في جيبك',
            bottom: Material(
              elevation: 6,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(18),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
                style: GoogleFonts.cairo(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'ابحث بعنوان الكتاب أو المؤلف',
                  hintStyle: GoogleFonts.cairo(color: Colors.black45),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search, color: kPrimary),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: kPrimary),
                    onPressed: _submit,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 54,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              scrollDirection: Axis.horizontal,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                label: Text(_suggestions[i],
                    style: GoogleFonts.cairo(fontSize: 13)),
                backgroundColor: scheme.surface,
                side: BorderSide(color: kPrimary.withOpacity(0.25)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                onPressed: () => _submit(_suggestions[i]),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Text(_sectionTitle,
                style: GoogleFonts.cairo(
                    fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ),
        if (_loading)
          const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: () => _fetch(_controller.text.trim()),
                      child: const Text('إعادة المحاولة')),
                ],
              ),
            ),
          )
        else if (_books.isEmpty)
          const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('لا توجد نتائج')))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.56,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => BookCard(
                    book: _books[i], onDownloaded: widget.onDownloaded),
                childCount: _books.length,
              ),
            ),
          ),
      ],
    );
  }
}
