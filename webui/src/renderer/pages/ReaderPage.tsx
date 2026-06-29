import React, { useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useReaderStore } from '@/store/readerStore';
import * as api from '@/lib/api';
import ReaderOverlay from '@/components/layout/ReaderOverlay';
import { Loader2 } from 'lucide-react';
import { determineReaderFormat, initialReaderPage } from './readerPageHelpers';

// Lazy-loaded so the heavy reader libraries (pdf.js, epub.js) are split into
// their own chunks and only fetched when a book is actually opened — they stay
// out of the initial library bundle.
const ComicReader = React.lazy(() => import('@/components/reader/ComicReader'));
const EpubReader = React.lazy(() => import('@/components/reader/EpubReader'));
const PdfReader = React.lazy(() => import('@/components/reader/PdfReader'));

export default function ReaderPage() {
  const { id, page } = useParams<{ id: string; page?: string }>();
  const comicId = Number(id);
  const navigate = useNavigate();

  const { currentPage, setCurrentPage, resetReader } = useReaderStore();
  const [extraControls, setExtraControls] = React.useState<React.ReactNode>(null);

  // Query to fetch comic record details. The reader resumes from
  // record.lastPage / lastLocation, so it must read the *latest* saved progress
  // every time it opens. Don't serve a stale cached record on SPA re-entry
  // (back button → reopen the same book): gcTime 0 drops the cache on unmount so
  // each open refetches — matching a full page refresh, which is exactly why
  // refresh resumed correctly but the back button reset to the start.
  const { data: record, isLoading, error } = useQuery<api.WebComicRecord>({
    queryKey: ['comic', comicId],
    queryFn: () => api.fetchComic(comicId),
    enabled: !isNaN(comicId),
    staleTime: 0,
    gcTime: 0,
  });

  // Sync initial page parameter from URL route or database history on load
  useEffect(() => {
    if (!record) return;

    setCurrentPage(initialReaderPage(page, record.lastPage));

    return () => {
      resetReader();
    };
  }, [page, record, setCurrentPage, resetReader]);

  if (isLoading) {
    return (
      <div className="flex flex-col items-center justify-center w-screen h-screen bg-black text-zinc-400 gap-3 select-none">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
        <span className="text-sm font-medium">Opening book...</span>
      </div>
    );
  }

  if (error || !record) {
    return (
      <div className="flex flex-col items-center justify-center w-screen h-screen bg-black text-zinc-400 gap-4 select-none">
        <p className="text-sm font-medium text-red-500">Failed to load reader.</p>
        <button
          onClick={() => navigate('/')}
          className="px-4 py-1.5 bg-zinc-800 hover:bg-zinc-700 text-white rounded text-xs transition-colors"
        >
          Go Back to Library
        </button>
      </div>
    );
  }

  // Determine which format view to mount
  const format = determineReaderFormat(record);

  const handlePageChange = (pageNum: number) => {
    setCurrentPage(pageNum);
    // Update the URL hash route to keep it synchronized (EPUB might use location string, handled in Phase 8)
    navigate(`/read/${comicId}/${pageNum}`, { replace: true });
  };

  const handleBack = () => {
    // Navigates back to the preceding library location (retains scroll position due to AppShell freezing)
    navigate(-1);
  };

  return (
    <ReaderOverlay
      title={record.title}
      currentPage={currentPage}
      pageCount={record.pageCount}
      onPageChange={handlePageChange}
      onBack={handleBack}
      extraControls={extraControls}
    >
      <React.Suspense
        fallback={
          <div className="flex items-center justify-center w-full h-full bg-black text-zinc-400">
            <Loader2 className="h-8 w-8 animate-spin text-primary" />
          </div>
        }
      >
        {format === 'comic' && (
          <ComicReader
            record={record}
            initialPage={currentPage}
            setExtraControls={setExtraControls}
          />
        )}
        {format === 'epub' && (
          <EpubReader
            record={record}
            initialLocation={page}
            setExtraControls={setExtraControls}
          />
        )}
        {format === 'pdf' && (
          <PdfReader
            record={record}
            initialPage={currentPage}
            setExtraControls={setExtraControls}
          />
        )}
      </React.Suspense>
    </ReaderOverlay>
  );
}
