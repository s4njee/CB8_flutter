import React, { useEffect } from 'react';
import { HashRouter } from 'react-router-dom';
import { QueryClientProvider } from '@tanstack/react-query';
import { queryClient, invalidateLibraryQueries } from './lib/queryClient';
import AppShell from './components/layout/AppShell';
import * as api from './lib/api';

/**
 * @module
 * Renderer Root Component
 *
 * Architecture overview for Junior Devs:
 * This is the top of the React tree. It does three jobs:
 *  1. Provides the React Query client to the whole app (`QueryClientProvider`),
 *     so any component can fetch/cache server data.
 *  2. Sets up hash-based routing (`HashRouter`) — hash routes work whether the
 *     bundle is loaded by Electron or directly from the server.
 *  3. Kicks off first-run session bootstrap in the background: checks for an
 *     existing login and auto-logs-in with the printed initial-admin password
 *     when needed. The shell renders immediately so startup never blocks on
 *     these network calls.
 */

/** The root component: providers, router, and background session bootstrap. */
export default function App() {
  useEffect(() => {
    async function bootstrap() {
      try {
        const session = await api.getSession();
        if (!session.authenticated) {
          const creds = await api.fetchInitialCredentials();
          if (creds?.initial_password) {
            const loggedIn = await api.adminLogin(creds.initial_password);
            if (loggedIn) {
              await queryClient.invalidateQueries({ queryKey: ['session'] });
              await queryClient.fetchQuery({
                queryKey: ['session'],
                queryFn: api.getSession,
              });
              // Refresh per-user catalog overlays now that we're authenticated.
              await invalidateLibraryQueries(queryClient);
            }
          }
        }
      } catch (err) {
        console.error('Session bootstrap failed:', err);
      }
    }

    void bootstrap();
  }, []);

  return (
    <QueryClientProvider client={queryClient}>
      <HashRouter>
        <AppShell />
      </HashRouter>
    </QueryClientProvider>
  );
}
