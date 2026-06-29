import { describe, expect, it } from 'vitest';
import {
  authResetPasswordLink,
  parseTrustedOriginExtras,
  resolveAuthBaseURL,
  trustedOriginsForBaseURL,
  withSameHostOrigin,
} from './authHelpers';

describe('authHelpers', () => {
  it('resolves the configured auth base URL with a localhost default', () => {
    expect(resolveAuthBaseURL(undefined)).toBe('http://localhost:8008');
    expect(resolveAuthBaseURL('https://cb8.example')).toBe('https://cb8.example');
  });

  it('builds SPA reset-password links with an encoded token', () => {
    expect(authResetPasswordLink('http://localhost:8008', 'a b/c?')).toBe(
      'http://localhost:8008/#/reset-password?token=a%20b%2Fc%3F',
    );
  });

  it('parses comma-separated trusted-origin extras', () => {
    expect(parseTrustedOriginExtras(' https://one.example, ,https://two.example ')).toEqual([
      'https://one.example',
      'https://two.example',
    ]);
    expect(parseTrustedOriginExtras(undefined)).toEqual([]);
  });

  it('expands trusted origins for loopback aliases, LAN IPs, and extras', () => {
    const origins = trustedOriginsForBaseURL(
      'http://localhost:8008',
      {
        en0: [
          { address: '192.168.1.50', family: 'IPv4', internal: false } as never,
          { address: '127.0.0.1', family: 'IPv4', internal: true } as never,
        ],
      },
      'https://cb8.example',
    );

    expect(origins).toEqual([
      'http://localhost:8008',
      'http://127.0.0.1:8008',
      'http://0.0.0.0:8008',
      'http://[::1]:8008',
      'http://192.168.1.50:8008',
      'https://cb8.example',
    ]);
  });

  it('keeps invalid base URLs without crashing', () => {
    expect(trustedOriginsForBaseURL('not a url', {}, undefined)).toEqual(['not a url']);
  });

  it('adds an origin only when it matches the request host', () => {
    expect(withSameHostOrigin(['http://localhost:8008'], 'http://cb8.local:8008', 'cb8.local:8008')).toEqual([
      'http://localhost:8008',
      'http://cb8.local:8008',
    ]);
    expect(withSameHostOrigin(['http://localhost:8008'], 'http://other.local:8008', 'cb8.local:8008')).toEqual([
      'http://localhost:8008',
    ]);
    expect(withSameHostOrigin(['http://localhost:8008'], 'bad url', 'cb8.local:8008')).toEqual([
      'http://localhost:8008',
    ]);
  });
});
