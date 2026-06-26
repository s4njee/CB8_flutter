import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/providers.dart';
import '../../data/sources/library_source.dart';
import '../connections/connection_switcher.dart';
import '../import/import_controller.dart';
import '../library/library_screen.dart';
import '../library/recent_screen.dart';
import '../organize/collections_screen.dart';
import '../organize/series_screen.dart';
import '../organize/tags_screen.dart';
import '../settings/settings_screen.dart';

/// One destination in the primary navigation.
class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon, this.body);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget body;
}

const _destinations = <_Destination>[
  _Destination('All', Icons.grid_view_outlined, Icons.grid_view, LibraryScreen()),
  _Destination('Recent', Icons.history_outlined, Icons.history, RecentScreen()),
  _Destination('Collections', Icons.collections_bookmark_outlined,
      Icons.collections_bookmark, CollectionsScreen()),
  _Destination('Folders', Icons.folder_outlined, Icons.folder, SeriesScreen()),
  _Destination('Tags', Icons.tag_outlined, Icons.tag, TagsScreen()),
];

/// App chrome with adaptive navigation: a bottom [NavigationBar] on phones and a
/// [NavigationRail] on wide layouts — the CB8 TabBar/Sidebar split.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Dev aid: `--dart-define=SEED=true` auto-loads sample comics on first run
    // (used to demo on a fresh simulator). No effect in normal builds.
    if (const bool.fromEnvironment('SEED')) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final existing =
            await ref.read(activeSourceProvider).listComics(const LibraryQuery(limit: 1));
        if (existing.isEmpty) {
          await ref.read(importControllerProvider.notifier).importSamples();
        }
      });
    }
    // Dev aid: `--dart-define=MOCK_SERVER=http://host:port` auto-adds that server
    // connection on first run so server mode can be exercised without typing.
    const mockServer = String.fromEnvironment('MOCK_SERVER');
    if (mockServer.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final state = ref.read(connectionsProvider);
        final exists = state.connections.any((c) => c.baseUrl == mockServer);
        if (!exists) {
          await ref.read(connectionsProvider.notifier).addConnection('Mock server', mockServer);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 768;
    final dest = _destinations[_index];

    // Surface import results as a snackbar.
    ref.listen<ImportState>(importControllerProvider, (prev, next) {
      if (prev?.running == true && !next.running && next.message != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(next.message!)));
      }
    });
    final importing = ref.watch(importControllerProvider).running;

    final appBar = AppBar(
      titleSpacing: 16,
      title: Row(
        children: [
          Text.rich(
            TextSpan(children: [
              const TextSpan(
                  text: 'CB', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              TextSpan(
                text: '8',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.primary),
              ),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(child: _SearchField()),
        ],
      ),
      actions: [
        const ConnectionSwitcher(),
        IconButton(
          icon: importing
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add),
          tooltip: 'Import files',
          onPressed:
              importing ? null : () => ref.read(importControllerProvider.notifier).pickAndImport(),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              backgroundColor: CbColors.surface,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: dest.body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: dest.body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _SearchField extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 38,
      child: TextField(
        onChanged: (v) => ref.read(libraryQueryProvider.notifier).setSearch(v),
        textAlignVertical: TextAlignVertical.center,
        decoration: const InputDecoration(
          hintText: 'Search',
          prefixIcon: Icon(Icons.search, size: 18),
          isDense: true,
        ),
      ),
    );
  }
}
