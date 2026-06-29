import type { NetworkInterfaceInfo } from 'node:os';

/**
 * @module
 * Auth URL & Trusted-Origin Helpers
 *
 * Architecture overview for Junior Devs:
 * The auth layer needs to know its own base URL (for building links like the
 * password-reset email) and which origins it should trust for CSRF/CORS purposes.
 * Because the app can be reached over localhost, loopback, or a LAN IP on the
 * same port, the trusted-origin list has to be computed from the machine's network
 * interfaces at runtime. These pure functions do that math without touching the
 * live server, so the (security-relevant) rules are easy to test.
 */

/** Fallback base URL when none is configured via the environment. */
export const DEFAULT_AUTH_BASE_URL = 'http://localhost:8008';

/**
 * Resolve the auth base URL, falling back to the default.
 * @param envValue The configured value from the environment, if any.
 * @returns The configured URL, or `DEFAULT_AUTH_BASE_URL` when unset.
 */
export function resolveAuthBaseURL(envValue: string | undefined): string {
  return envValue || DEFAULT_AUTH_BASE_URL;
}

/**
 * Build the front-end password-reset link for a given token.
 * @param baseURL The app base URL.
 * @param token The reset token (URL-encoded into the link).
 * @returns The full reset-password URL.
 */
export function authResetPasswordLink(baseURL: string, token: string): string {
  return `${baseURL}/#/reset-password?token=${encodeURIComponent(token)}`;
}

/**
 * Parse a comma-separated list of extra trusted origins.
 * @param raw The raw env value, if any.
 * @returns Trimmed, non-empty origin strings (empty array when unset).
 */
export function parseTrustedOriginExtras(raw: string | undefined): string[] {
  if (!raw) return [];
  return raw
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
}

/**
 * Compute the full set of trusted origins for the configured base URL.
 * Starts from the base URL, adds the standard loopback hosts on the same
 *          port, then every non-internal IPv4 LAN address (so the app works when
 *          reached from another device), and finally any explicitly configured
 *          extras. An unparseable base URL is kept as-is.
 * @param baseURL The app base URL.
 * @param networkInterfaces The machine's network interfaces (from `os.networkInterfaces()`).
 * @param extraOrigins Comma-separated extra origins from configuration, if any.
 * @returns A de-duplicated list of trusted origins.
 */
export function trustedOriginsForBaseURL(
  baseURL: string,
  networkInterfaces: NodeJS.Dict<NetworkInterfaceInfo[]>,
  extraOrigins: string | undefined,
): string[] {
  const out = new Set<string>([baseURL]);
  try {
    const parsed = new URL(baseURL);
    const port = parsed.port || (parsed.protocol === 'https:' ? '443' : '80');
    for (const host of ['localhost', '127.0.0.1', '0.0.0.0', '[::1]']) {
      out.add(`${parsed.protocol}//${host}:${port}`);
    }
    for (const list of Object.values(networkInterfaces)) {
      for (const iface of list ?? []) {
        if (iface.family === 'IPv4' && !iface.internal) {
          out.add(`${parsed.protocol}//${iface.address}:${port}`);
        }
      }
    }
  } catch {
    // Keep the configured base URL even if it is not parseable.
  }

  for (const origin of parseTrustedOriginExtras(extraOrigins)) {
    out.add(origin);
  }
  return Array.from(out);
}

/**
 * Conditionally trust a request's Origin when it matches the Host header.
 * Lets a request through when its `Origin` and `Host` refer to the same
 *          host (covers dynamic LAN access not known at startup). Invalid Origin
 *          headers are ignored.
 * @param trustedOrigins The base trusted-origin list.
 * @param origin The request `Origin` header, if present.
 * @param host The request `Host` header, if present.
 * @returns The trusted-origin list, possibly extended with the request origin.
 */
export function withSameHostOrigin(trustedOrigins: string[], origin: string | null | undefined, host: string | null | undefined): string[] {
  const out = new Set<string>(trustedOrigins);
  try {
    if (origin && host) {
      const parsed = new URL(origin);
      if (parsed.host === host) out.add(origin);
    }
  } catch {
    // Ignore invalid Origin headers.
  }
  return Array.from(out);
}
