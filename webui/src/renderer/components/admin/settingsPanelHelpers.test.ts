import { describe, expect, it } from 'vitest';
import {
  THEME_LIST,
  autoRescanSavedMessage,
  clearLibraryRemovedMessage,
  parseAutoRescanMinutes,
  parseWebServerPort,
} from './settingsPanelHelpers';

describe('settingsPanelHelpers', () => {
  it('defines the expected theme swatches', () => {
    expect(THEME_LIST.map((theme) => theme.id)).toEqual(['red', 'blue', 'green', 'purple', 'orange', 'teal']);
  });

  it('parses non-negative auto-rescan intervals', () => {
    expect(parseAutoRescanMinutes('0')).toBe(0);
    expect(parseAutoRescanMinutes('15')).toBe(15);
    expect(parseAutoRescanMinutes('-1')).toBeNull();
    expect(parseAutoRescanMinutes('nope')).toBeNull();
  });

  it('formats auto-rescan saved messages', () => {
    expect(autoRescanSavedMessage(0)).toBe('Auto-rescan disabled.');
    expect(autoRescanSavedMessage(1)).toBe('Folders will rescan every 1 minute.');
    expect(autoRescanSavedMessage(5)).toBe('Folders will rescan every 5 minutes.');
  });

  it('parses valid web server ports only', () => {
    expect(parseWebServerPort('1024')).toBe(1024);
    expect(parseWebServerPort('65535')).toBe(65535);
    expect(parseWebServerPort('1023')).toBeNull();
    expect(parseWebServerPort('65536')).toBeNull();
    expect(parseWebServerPort('nope')).toBeNull();
  });

  it('formats clear-library removal messages', () => {
    expect(clearLibraryRemovedMessage(1)).toBe('Library cleared (1 item removed).');
    expect(clearLibraryRemovedMessage(1200)).toBe('Library cleared (1,200 items removed).');
  });
});
