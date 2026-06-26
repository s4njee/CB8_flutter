import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../data/local_files.dart';
import '../../../data/models/comic_summary.dart';
import '../../../data/repositories/providers.dart';
import '../comic/reading_mode.dart';
import '../reader_keyboard.dart';

/// PDF reader built on pdfrx's native [PdfViewer] — renders the document as
/// crisp vectors (re-rasterized per zoom level), and streams large PDFs without
/// the memory/concurrency problems of rasterizing every page to an image.
///
/// The three reading modes map onto pdfrx's custom-layout API:
///  - scroll      → continuous vertical (pdfrx's native mode)
///  - single      → pages laid out horizontally, one per "screen", tap to page
///  - doublePage  → pages laid out horizontally in pairs (two-page spread)
///
/// Pinch-zoom is built in. Tap zones (left/right thirds) turn pages in the paged
/// modes; the centre toggles the chrome.
class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({super.key, required this.comic});

  final ComicSummary comic;

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  final PdfViewerController _controller = PdfViewerController();
  String? _path;
  String? _error;
  int _page = 0; // 0-based current page
  int _pageCount = 0;
  bool _chrome = true;

  @override
  void initState() {
    super.initState();
    _page = widget.comic.lastPage ?? 0;
    _pageCount = widget.comic.pageCount;
    _resolve();
  }

  Future<void> _resolve() async {
    final uri = widget.comic.sourceUri;
    if (uri == null) {
      setState(() => _error = 'Could not open this PDF.');
      return;
    }
    final abs = await resolveLibraryPath(uri);
    if (mounted) setState(() => _path = abs);
  }

  void _saveProgress(int page) {
    final completed = _pageCount > 0 && page >= _pageCount - 1;
    ref.read(activeSourceProvider).setProgress(
          widget.comic.id,
          page: page,
          completed: completed ? true : null,
        );
  }

  /// Lay pages out for the active reading mode. Returns one rect per page (in
  /// page order) plus the overall document size.
  PdfPageLayout _layout(ReadingMode mode, List<PdfPage> pages, PdfViewerParams params) {
    final m = params.margin;
    switch (mode) {
      case ReadingMode.scroll:
        // Continuous vertical (pdfrx's default).
        final width = pages.fold(0.0, (w, p) => math.max(w, p.width)) + m * 2;
        final rects = <Rect>[];
        var y = m;
        for (final p in pages) {
          rects.add(Rect.fromLTWH((width - p.width) / 2, y, p.width, p.height));
          y += p.height + m;
        }
        return PdfPageLayout(pageLayouts: rects, documentSize: Size(width, y));

      case ReadingMode.single:
        // Pages side by side horizontally; one fills the view, swipe/tap to page.
        final height = pages.fold(0.0, (h, p) => math.max(h, p.height)) + m * 2;
        final rects = <Rect>[];
        var x = m;
        for (final p in pages) {
          rects.add(Rect.fromLTWH(x, (height - p.height) / 2, p.width, p.height));
          x += p.width + m;
        }
        return PdfPageLayout(pageLayouts: rects, documentSize: Size(x, height));

      case ReadingMode.doublePage:
        // Pairs of pages laid out horizontally, larger gap between spreads.
        final height = pages.fold(0.0, (h, p) => math.max(h, p.height)) + m * 2;
        final rects = List<Rect>.filled(pages.length, Rect.zero, growable: false);
        var x = m;
        for (var i = 0; i < pages.length; i += 2) {
          final left = pages[i];
          rects[i] = Rect.fromLTWH(x, (height - left.height) / 2, left.width, left.height);
          var nx = x + left.width;
          if (i + 1 < pages.length) {
            final right = pages[i + 1];
            nx += m;
            rects[i + 1] = Rect.fromLTWH(nx, (height - right.height) / 2, right.width, right.height);
            nx += right.width;
          }
          x = nx + m * 4;
        }
        return PdfPageLayout(pageLayouts: rects, documentSize: Size(x, height));
    }
  }

  void _turn(ReadingMode mode, {required bool forward}) {
    final step = mode == ReadingMode.doublePage ? 2 : 1;
    final cur = _controller.isReady ? (_controller.pageNumber ?? _page + 1) : _page + 1;
    final maxPage = _pageCount > 0 ? _pageCount : cur;
    final target = forward ? cur + step : cur - step;
    if (target < 1 || target > maxPage) return;
    _controller.goToPage(pageNumber: target, anchor: PdfPageAnchor.all);
  }

  void _handleTap(ReadingMode mode, Offset position) {
    final width = MediaQuery.sizeOf(context).width;
    if (mode != ReadingMode.scroll && position.dx < width * 0.33) {
      _turn(mode, forward: false);
    } else if (mode != ReadingMode.scroll && position.dx > width * 0.67) {
      _turn(mode, forward: true);
    } else {
      setState(() => _chrome = !_chrome);
    }
  }

  void _jumpTo(int page) {
    _controller.goToPage(
      pageNumber: (page + 1).clamp(1, _pageCount == 0 ? 1 : _pageCount),
      anchor: PdfPageAnchor.all,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(readingModeProvider);
    final path = _path;
    return Scaffold(
      backgroundColor: Colors.black,
      body: ReaderKeyboard(
        onNext: () => _turn(mode, forward: true),
        onPrev: () => _turn(mode, forward: false),
        onFirst: () => _jumpTo(0),
        onLast: () => _jumpTo(_pageCount > 0 ? _pageCount - 1 : 0),
        child: Stack(
        children: [
          if (_error != null)
            _PdfMessage(message: _error!)
          else if (path == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            PdfViewer.file(
              path,
              // Remount on mode change so the new page layout takes effect.
              key: ValueKey(mode),
              controller: _controller,
              initialPageNumber: (_page + 1).clamp(1, 1 << 30),
              params: PdfViewerParams(
                backgroundColor: Colors.black,
                margin: 8,
                panAxis: PanAxis.free,
                // Fit the whole page to the viewport on navigation (and on first
                // open) — the default `.top` anchor preserves zoom, which left
                // pages blown up far past the viewport width.
                pageAnchor: PdfPageAnchor.all,
                layoutPages: (pages, params) => _layout(mode, pages, params),
                onViewerReady: (document, controller) {
                  if (mounted) setState(() => _pageCount = document.pages.length);
                  // The viewer's own initial goToPage runs before the viewport is
                  // measured, so the resume page can open zoomed-in past fit.
                  // Re-fit once a frame after ready, when sizing is settled.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    controller.goToPage(
                      pageNumber: (_page + 1).clamp(1, document.pages.length),
                      anchor: PdfPageAnchor.all,
                    );
                  });
                },
                onPageChanged: (pageNumber) {
                  if (pageNumber == null) return;
                  final p = pageNumber - 1;
                  if (p != _page) {
                    _page = p;
                    _saveProgress(p);
                    if (mounted) setState(() {});
                  }
                },
              ),
            ),
            // Tap layer ABOVE the viewer: captures taps (turn page / toggle
            // chrome) while pan/zoom drags fall through to the viewer below.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (d) => _handleTap(mode, d.localPosition),
              ),
            ),
          ],
          if (_chrome) _topBar(context, mode),
          if (_chrome && path != null) _bottomBar(context),
        ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, ReadingMode mode) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Text(
                widget.comic.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            PopupMenuButton<ReadingMode>(
              tooltip: 'Reading mode',
              icon: Icon(mode.icon, color: Colors.white),
              onSelected: (m) => ref.read(readingModeProvider.notifier).set(m),
              itemBuilder: (context) => [
                for (final m in ReadingMode.values)
                  CheckedPopupMenuItem(
                    value: m,
                    checked: m == mode,
                    child: Row(
                      children: [
                        Icon(m.icon, size: 18),
                        const SizedBox(width: 10),
                        Text(m.label),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final count = _pageCount;
    final maxVal = math.max(0.0, (count - 1).toDouble());
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 8,
          top: 8,
          left: 12,
          right: 12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Slider(
                value: _page.toDouble().clamp(0.0, maxVal),
                min: 0,
                max: maxVal,
                onChanged: count > 1 ? (v) => _jumpTo(v.round()) : null,
              ),
            ),
            const SizedBox(width: 8),
            Text('${_page + 1} / $count', style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _PdfMessage extends StatelessWidget {
  const _PdfMessage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
