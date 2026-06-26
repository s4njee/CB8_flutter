import 'package:go_router/go_router.dart';

import '../../features/reader/reader_dispatcher.dart';
import '../../features/shell/app_shell.dart';

/// Top-level router. Routes mirror CB8 (`AppShell.tsx`). `/read/:id` opens the
/// format-appropriate reader for a catalog item on the active source.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AppShell(),
      routes: [
        GoRoute(
          path: 'read/:id',
          builder: (context, state) =>
              ReaderDispatcher(comicId: state.pathParameters['id']!),
        ),
      ],
    ),
  ],
);
