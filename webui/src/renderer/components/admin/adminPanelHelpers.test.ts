import { describe, expect, it } from 'vitest';
import {
  adminPanelAfterLogin,
  adminPanelTitle,
  initialAdminPanelForRequest,
  isProtectedAdminPanel,
  toAdminPanel,
} from './adminPanelHelpers';

describe('adminPanelHelpers', () => {
  it('accepts only known admin panels', () => {
    expect(toAdminPanel('upload')).toBe('upload');
    expect(toAdminPanel('not-a-panel')).toBeNull();
    expect(toAdminPanel(null)).toBeNull();
  });

  it('requires login before protected panels when unauthenticated', () => {
    expect(initialAdminPanelForRequest('upload', false)).toBe('login');
    expect(initialAdminPanelForRequest('settings', false)).toBe('login');
    expect(initialAdminPanelForRequest('signup', false)).toBe('signup');
    expect(initialAdminPanelForRequest(null, false)).toBe('menu');
  });

  it('opens requested protected panels after authentication', () => {
    expect(initialAdminPanelForRequest('upload', true)).toBe('upload');
    expect(adminPanelAfterLogin('add-path')).toBe('add-path');
    expect(adminPanelAfterLogin('login')).toBe('menu');
  });

  it('keeps modal titles in one lookup table', () => {
    expect(adminPanelTitle('create-folder')).toBe('New folder');
    expect(adminPanelTitle('menu')).toBe('Admin');
    expect(isProtectedAdminPanel('users')).toBe(true);
    expect(isProtectedAdminPanel('forgot')).toBe(false);
  });
});
