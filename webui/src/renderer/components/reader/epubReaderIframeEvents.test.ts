import { describe, expect, it, vi } from 'vitest';
import {
  attachEpubIframeInteractions,
  createEpubKeyboardHandler,
  epubDocumentFromRenderedView,
} from './epubReaderIframeEvents';

type ListenerMap = Record<string, EventListener[]>;

function createFakeDocument() {
  const listeners: ListenerMap = {};
  const doc = {
    defaultView: { innerWidth: 300 },
    addEventListener: vi.fn((eventName: string, listener: EventListener) => {
      listeners[eventName] ??= [];
      listeners[eventName].push(listener);
    }),
  };
  return {
    doc: doc as unknown as Document,
    listeners,
  };
}

function createRendition() {
  return {
    next: vi.fn(),
    prev: vi.fn(),
    display: vi.fn(() => Promise.resolve()),
  };
}

describe('epubReaderIframeEvents', () => {
  it('finds an iframe document from either epub.js view shape', () => {
    const direct = createFakeDocument().doc;
    const nested = createFakeDocument().doc;

    expect(epubDocumentFromRenderedView({ document: direct })).toBe(direct);
    expect(epubDocumentFromRenderedView({ contents: { document: nested } })).toBe(nested);
    expect(epubDocumentFromRenderedView(null)).toBeNull();
  });

  it('turns keyboard events into rendition navigation', () => {
    const rendition = createRendition();
    const handler = createEpubKeyboardHandler(rendition);
    const right = { key: 'ArrowRight', preventDefault: vi.fn(), target: { tagName: 'BODY' } } as unknown as KeyboardEvent;
    const left = { key: 'ArrowLeft', preventDefault: vi.fn(), target: { tagName: 'BODY' } } as unknown as KeyboardEvent;
    const input = { key: 'ArrowRight', preventDefault: vi.fn(), target: { tagName: 'INPUT' } } as unknown as KeyboardEvent;

    handler(right);
    handler(left);
    handler(input);

    expect(right.preventDefault).toHaveBeenCalledOnce();
    expect(left.preventDefault).toHaveBeenCalledOnce();
    expect(input.preventDefault).not.toHaveBeenCalled();
    expect(rendition.next).toHaveBeenCalledOnce();
    expect(rendition.prev).toHaveBeenCalledOnce();
  });

  it('wires an iframe document once and resolves internal links through rendition.display', () => {
    const { doc, listeners } = createFakeDocument();
    const rendition = createRendition();
    const linkedDocs = new WeakSet<Document>();
    const resolveDisplayTarget = vi.fn(() => 'chapter-target');

    attachEpubIframeInteractions({
      iframeDoc: doc,
      rendition,
      keyboardHandler: vi.fn(),
      sectionHref: 'chapter.xhtml',
      resolveDisplayTarget,
      linkedIframeDocs: linkedDocs,
      onLinkError: vi.fn(),
    });
    attachEpubIframeInteractions({
      iframeDoc: doc,
      rendition,
      keyboardHandler: vi.fn(),
      sectionHref: 'chapter.xhtml',
      resolveDisplayTarget,
      linkedIframeDocs: linkedDocs,
      onLinkError: vi.fn(),
    });

    expect(listeners.click).toHaveLength(1);
    expect(listeners.keydown).toHaveLength(1);
    expect(listeners.touchstart).toHaveLength(1);

    const link = { getAttribute: vi.fn(() => '#footnote') };
    const event = {
      target: { closest: vi.fn(() => link) },
      preventDefault: vi.fn(),
      stopPropagation: vi.fn(),
      stopImmediatePropagation: vi.fn(),
    } as unknown as MouseEvent;

    listeners.click[0](event);

    expect(resolveDisplayTarget).toHaveBeenCalledWith('#footnote', 'chapter.xhtml');
    expect(event.preventDefault).toHaveBeenCalledOnce();
    expect(event.stopPropagation).toHaveBeenCalledOnce();
    expect(event.stopImmediatePropagation).toHaveBeenCalledOnce();
    expect(rendition.display).toHaveBeenCalledWith('chapter-target');
  });

  it('maps iframe swipes and taps to navigation or toolbar actions', () => {
    const { doc, listeners } = createFakeDocument();
    const rendition = createRendition();
    const dispatchToolbarToggle = vi.fn();

    attachEpubIframeInteractions({
      iframeDoc: doc,
      rendition,
      keyboardHandler: vi.fn(),
      resolveDisplayTarget: vi.fn(),
      linkedIframeDocs: new WeakSet<Document>(),
      onLinkError: vi.fn(),
      getViewportWidth: () => 300,
      dispatchToolbarToggle,
    });

    listeners.touchstart[0]({
      touches: [{ clientX: 250, clientY: 20 }],
    } as unknown as TouchEvent);
    listeners.touchend[0]({
      changedTouches: [{ clientX: 100, clientY: 25 }],
      preventDefault: vi.fn(),
      target: { closest: vi.fn(() => null) },
    } as unknown as TouchEvent);

    listeners.touchstart[0]({
      touches: [{ clientX: 150, clientY: 20 }],
    } as unknown as TouchEvent);
    listeners.touchend[0]({
      changedTouches: [{ clientX: 150, clientY: 20 }],
      preventDefault: vi.fn(),
      target: { closest: vi.fn(() => null) },
    } as unknown as TouchEvent);

    expect(rendition.next).toHaveBeenCalledOnce();
    expect(dispatchToolbarToggle).toHaveBeenCalledOnce();
  });
});
