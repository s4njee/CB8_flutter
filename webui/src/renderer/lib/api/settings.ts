import { del, get, put } from './client';
import type { InitialCredentials } from './types';

export const setGuestAccess = (enabled: boolean): Promise<void> =>
  put<void>('/api/settings/guest-access', { body: { enabled }, parse: 'none' });

export const fetchAutoRescanInterval = (): Promise<{ minutes: number }> =>
  get<{ minutes: number }>('/api/settings/auto-rescan-interval');

export const setAutoRescanInterval = (minutes: number): Promise<void> =>
  put<void>('/api/settings/auto-rescan-interval', { body: { minutes }, parse: 'none' });

export async function fetchInitialCredentials(): Promise<InitialCredentials | null> {
  const creds = await get<InitialCredentials | null>('/api/settings/initial-credentials');
  if (!creds) return null;
  return {
    ...creds,
    initial_password: creds.initial_password ?? creds.password ?? null,
  };
}

export const clearInitialCredentials = (): Promise<void> =>
  del<void>('/api/settings/initial-credentials', { parse: 'none' });
