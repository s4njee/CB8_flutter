/**
 * @module
 * Reader Page Setup Helpers
 *
 * Architecture overview for Junior Devs:
 * When the reader page opens, it has to answer two questions before it can render:
 * which page to start on, and which reader to use (the comic image reader, the
 * EPUB reader, or the PDF reader). This module holds those two pure decisions.
 *
 * Note `determineReaderFormat`: extension and media type give a confident answer
 * for most files, but some books lack a reliable extension, so it falls back to
 * heuristics based on stored reading-progress shape (e.g. an EPUB CFI location vs.
 * a numeric PDF page) to pick the best reader.
 */

/** The reader UI to render for a given item. */
export type ReaderFormat = 'comic' | 'epub' | 'pdf';

/** The subset of a media record needed to choose a reader format. */
export interface ReaderFormatRecord {
  mediaType: 'comic' | 'book';
  fileExt: string;
  pageCount: number;
  lastPage: number | null;
  lastLocation: string | null;
}

/**
 * Decide which page the reader should open on.
 * Honours an explicit, valid (>0) page from the route; otherwise resumes
 *          just after the last-read page, or starts at page 1 if there is none.
 * @param routePage The page number from the URL, if any.
 * @param lastPage The last-read page index, or `null` if never read.
 * @returns The 1-based page to open on.
 */
export function initialReaderPage(routePage: string | undefined, lastPage: number | null): number {
  if (routePage) {
    const pageNumber = parseInt(routePage, 10);
    if (!isNaN(pageNumber) && pageNumber > 0) {
      return pageNumber;
    }
  }

  return lastPage === null ? 1 : lastPage + 1;
}

/**
 * Determine which reader UI to use for a media record.
 * Resolves confidently by media type / extension first (comic, cbz, cbr,
 *          epub, pdf). For books with an ambiguous extension it falls back to
 *          progress-shape heuristics: no pages/progress or an `epubcfi` location
 *          implies EPUB; a positive page count with no location implies PDF;
 *          otherwise it defaults to EPUB.
 * @param record The media record's format-relevant fields.
 * @returns The reader format to render.
 */
export function determineReaderFormat(record: ReaderFormatRecord): ReaderFormat {
  const ext = (record.fileExt || '').toLowerCase();

  if (record.mediaType === 'comic' || ext === 'cbz' || ext === 'cbr') {
    return 'comic';
  }
  if (ext === 'epub') return 'epub';
  if (ext === 'pdf') return 'pdf';

  if (record.pageCount === 0 && !record.lastPage) return 'epub';
  if (record.lastLocation && record.lastLocation.includes('epubcfi')) return 'epub';
  if (record.pageCount > 0 && !record.lastLocation) return 'pdf';
  return 'epub';
}
