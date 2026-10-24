import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'common.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => LibraryTabState();
}

class LibraryTabState extends State<LibraryTab> {
  List<File> _files = [];

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final dir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${dir.path}/books');
    if (await booksDir.exists()) {
      final files = booksDir.listSync().whereType<File>().toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      if (mounted) setState(() => _files = files);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        GradientHeader(
          subtitle: _files.isEmpty
              ? 'مكتبتك فارغة'
              : 'لديك ${_files.length} كتاب جاهز للقراءة',
        ),
        Expanded(
          child: _files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_stories_outlined,
                          size: 72, color: kPrimary.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('لا توجد كتب محمّلة بعد',
                          style: GoogleFonts.cairo(fontSize: 16)),
                      Text('ابدأ من تبويب استكشف',
                          style: GoogleFonts.cairo(
                              color: scheme.onSurface.withOpacity(0.6))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _files.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final f = _files[i];
                      final name = f.path.split('/').last;
                      final dot = name.lastIndexOf('.');
                      final title = dot > 0 ? name.substring(0, dot) : name;
                      final ext =
                          dot > 0 ? name.substring(dot + 1).toUpperCase() : '';
                      return Container(
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 3)),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                          leading: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: kPrimary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.menu_book_rounded,
                                color: kPrimary),
                          ),
                          title: Text(title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(ext,
                              style: GoogleFonts.cairo(
                                  fontSize: 12, color: kAccent)),
                          onTap: () => OpenFilex.open(f.path),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await f.delete();
                              reload();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
