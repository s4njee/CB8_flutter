/**
 * @module
 * Admin Panel Routing & Access Helpers
 *
 * Architecture overview for Junior Devs:
 * The admin area is a single component that swaps between several "panels" (menu,
 * login, settings, upload, etc.). This module is the source of truth for which
 * panels exist, which require authentication, and what each one is titled — plus
 * the small rules for validating a requested panel and deciding which panel to
 * show given the auth state. Centralising this keeps the routing decisions
 * consistent and unit-testable, separate from the rendering component.
 */

/** Every admin panel the admin area can display, in definition order. */
export const ADMIN_PANELS = [
  'menu',
  'login',
  'signup',
  'forgot',
  'reset',
  'add-path',
  'upload',
  'users',
  'settings',
  'create-collection',
  'create-folder',
] as const;

/** Union of valid admin panel identifiers. */
export type AdminPanel = typeof ADMIN_PANELS[number];

/** Fast lookup set for validating arbitrary panel strings. */
const adminPanelSet = new Set<string>(ADMIN_PANELS);

/** Panels that require an authenticated user. */
const protectedPanels = new Set<AdminPanel>([
  'upload',
  'add-path',
  'settings',
  'users',
  'create-collection',
  'create-folder',
]);

/** Display title for each admin panel. */
const panelTitles: Record<AdminPanel, string> = {
  menu: 'Admin',
  login: 'Sign in',
  signup: 'Create account',
  forgot: 'Reset password',
  reset: 'Set a new password',
  'add-path': 'Add from server path',
  upload: 'Upload comics',
  users: 'User Management',
  settings: 'Settings',
  'create-collection': 'New collection',
  'create-folder': 'New folder',
};

/**
 * Validate an arbitrary string as a known admin panel.
 * @param panel The candidate panel string.
 * @returns The typed panel if recognised, otherwise `null`.
 */
export function toAdminPanel(panel: string | null | undefined): AdminPanel | null {
  return panel && adminPanelSet.has(panel) ? (panel as AdminPanel) : null;
}

/**
 * Whether a panel requires authentication to view (type guard).
 * @param panel The panel to check.
 * @returns `true` (narrowing to `AdminPanel`) if the panel is protected.
 */
export function isProtectedAdminPanel(panel: AdminPanel | null | undefined): panel is AdminPanel {
  return Boolean(panel && protectedPanels.has(panel));
}

/**
 * Choose the panel to show for an initial request, enforcing auth.
 * Redirects to `login` when a protected panel is requested by an
 *          unauthenticated user; otherwise honours the request or falls back to `menu`.
 * @param requestedPanel The panel the user asked for, if any.
 * @param isAuthenticated Whether the user is signed in.
 * @returns The panel to display.
 */
export function initialAdminPanelForRequest(
  requestedPanel: AdminPanel | null,
  isAuthenticated: boolean
): AdminPanel {
  if (isProtectedAdminPanel(requestedPanel) && !isAuthenticated) {
    return 'login';
  }
  return requestedPanel ?? 'menu';
}

/**
 * Choose the panel to show after a successful login.
 * Returns the originally requested protected panel (resuming the user's
 *          intent), or `menu` if there was no protected target.
 * @param requestedPanel The panel requested before login, if any.
 * @returns The panel to display post-login.
 */
export function adminPanelAfterLogin(requestedPanel: AdminPanel | null): AdminPanel {
  if (requestedPanel && isProtectedAdminPanel(requestedPanel)) {
    return requestedPanel;
  }
  return 'menu';
}

/**
 * Get the display title for a panel.
 * @param panel The panel.
 * @returns The human-readable title.
 */
export function adminPanelTitle(panel: AdminPanel): string {
  return panelTitles[panel];
}
