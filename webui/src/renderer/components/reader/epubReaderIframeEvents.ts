import type { EpubRendition } from './EpubReaderTypes';
import {
  EPUB_INTERACTIVE_TAP_SELECTOR,
  epubKeyboardAction,
  epubSwipeAction,
  epubTapAction,
} from './epubReaderInteractions';

type EpubRenderedView = {
  document?: Document;
  contents?: {
    document?: Document;
  };
};

interface EpubIframeInteractionOptions {
  iframeDoc: Document;
  rendition: Pick<EpubRendition, 'next' | 'prev' | 'display'>;
  keyboardHandler: (event: KeyboardEvent) => void;
  sectionHref?: string | null;
  resolveDisplayTarget: (href: string, sectionHref?: string | null) => string | number | null;
  linkedIframeDocs: WeakSet<Document>;
  onLinkError: (error: unknown) => void;
  getViewportWidth?: () => number;
  dispatchToolbarToggle?: () => void;
}

/**
 * @module
 * EPUB iframe event wiring
 *
 * Architecture overview for Junior Devs:
 * epub.js renders chapters inside iframe documents. This module owns the event
 * listeners that must be installed inside those iframe documents: keyboard page
 * turns, internal link clicks, touch swipes, and tap zones. Keeping this here
 * keeps `EpubReader.tsx` focused on epub.js lifecycle and React state.
 */

export function epubDocumentFromRenderedView(view: EpubRenderedView | null | undefined): Document | null {
  return view?.document || view?.contents?.document || null;
}

export function createEpubKeyboardHandler(
  rendition: Pick<EpubRendition, 'next' | 'prev'>,
): (event: KeyboardEvent) => void {
  return (event) => {
    const action = epubKeyboardAction(event.key, (event.target as HTMLElement | null)?.tagName);
    if (!action) return;
    event.preventDefault();
    if (action === 'next') rendition.next();
    else rendition.prev();
  };
}

export function attachEpubIframeInteractions({
  iframeDoc,
  rendition,
  keyboardHandler,
  sectionHref,
  resolveDisplayTarget,
  linkedIframeDocs,
  onLinkError,
  getViewportWidth = () => iframeDoc.defaultView?.innerWidth ?? window.innerWidth,
  dispatchToolbarToggle = () => window.dispatchEvent(new CustomEvent('cb8:reader-toggle-toolbar')),
}: EpubIframeInteractionOptions): void {
  if (linkedIframeDocs.has(iframeDoc)) return;
  linkedIframeDocs.add(iframeDoc);

  iframeDoc.addEventListener('keydown', keyboardHandler);
  iframeDoc.addEventListener('click', (event: MouseEvent) => {
    const target = event.target as Element | null;
    const link = target?.closest('a[href]');
    if (!link) return;

    const href = link.getAttribute('href') || '';
    const displayTarget = resolveDisplayTarget(href, sectionHref);
    if (!displayTarget) return;

    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation();
    void rendition.display(displayTarget).catch(onLinkError);
  }, { capture: true });

  let txStart = 0;
  let tyStart = 0;

  iframeDoc.addEventListener('touchstart', (event: TouchEvent) => {
    if (event.touches.length === 1) {
      txStart = event.touches[0].clientX;
      tyStart = event.touches[0].clientY;
    }
  }, { passive: true });

  iframeDoc.addEventListener('touchcancel', () => {
    txStart = 0;
    tyStart = 0;
  }, { passive: true });

  iframeDoc.addEventListener('touchend', (event: TouchEvent) => {
    if (!event.changedTouches.length) return;
    const touch = event.changedTouches[0];
    const dx = touch.clientX - txStart;
    const dy = touch.clientY - tyStart;

    const swipeAction = epubSwipeAction(dx, dy);
    if (swipeAction) {
      event.preventDefault();
      if (swipeAction === 'next') rendition.next();
      else rendition.prev();
      return;
    }

    const target = event.target as Element | null;
    const tapAction = epubTapAction(
      dx,
      dy,
      touch.clientX,
      getViewportWidth(),
      Boolean(target?.closest(EPUB_INTERACTIVE_TAP_SELECTOR)),
    );
    if (tapAction === 'prev') rendition.prev();
    else if (tapAction === 'next') rendition.next();
    else if (tapAction === 'toolbar') dispatchToolbarToggle();
  }, { passive: false });
}
