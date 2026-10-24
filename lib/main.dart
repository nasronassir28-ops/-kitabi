import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const KitabiApp());

const kPrimary = Color(0xFF0F766E);
const kPrimaryDark = Color(0xFF115E59);
const kAccent = Color(0xFFF59E0B);

ThemeData _buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: kPrimary, brightness: b);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final isLight = b == Brightness.light;
  return base.copyWith(
    textTheme: GoogleFonts.cairoTextTheme(base.textTheme),
    scaffoldBackgroundColor:
        isLight ? const Color(0xFFFAF7F2) : const Color(0xFF121614),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      indicatorColor: kPrimary.withOpacity(0.15),
      labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );
}

class KitabiApp extends StatelessWidget {
  const KitabiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'كتابي',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const HomePage(),
    );
  }
}

class Book {
  final int id;
  final String title;
  final String author;
  final String? downloadUrl;
  final String? coverUrl;
  final String ext;
  final bool copyrighted;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.downloadUrl,
    required this.coverUrl,
    required this.ext,
    required this.copyrighted,
  });

  bool get canDownload => downloadUrl != null && !copyrighted;

  factory Book.fromJson(Map<String, dynamic> j) {
    final formats = Map<String, dynamic>.from(j['formats'] ?? {});
    String? url;
    String ext = 'epub';
    if (formats['application/epub+zip'] != null) {
      url = formats['application/epub+zip'];
    } else if (formats['application/pdf'] != null) {
      url = formats['application/pdf'];
      ext = 'pdf';
    }
    final authors = (j['authors'] as List?) ?? [];
    return Book(
      id: j['id'],
      title: j['title'] ?? 'بدون عنوان',
      author: authors.isNotEmpty ? authors.first['name'] : 'مؤلف غير معروف',
      downloadUrl: url,
      coverUrl: formats['image/jpeg'],
      ext: ext,
      copyrighted: j['copyright'] == true,
    );
  }
}

class GradientHeader extends StatelessWidget {
  final String subtitle;
  final Widget? bottom;
  const GradientHeader({super.key, required this.subtitle, this.bottom});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [kPrimary, kPrimaryDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_stories, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text('كتابي',
                  style: GoogleFonts.cairo(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle,
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14)),
          if (bottom != null) ...[const SizedBox(height: 18), bottom!],
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  final _libraryKey = GlobalKey<_LibraryTabState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          SearchTab(onDownloaded: () => _libraryKey.currentState?.reload()),
          LibraryTab(key: _libraryKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 1) _libraryKey.currentState?.reload();
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'استكشف'),
          NavigationDestination(
              icon: Icon(Icons.bookmarks_outlined),
              selectedIcon: Icon(Icons.bookmarks),
              label: 'مكتبتي'),
        ],
      ),
    );
  }
}

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
