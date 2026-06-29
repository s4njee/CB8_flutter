export interface OkResponse {
  ok: true;
}

export interface InitialCredentialsResponse {
  username: string;
  password: string | null;
  /** Renderer-normalized alias for older/newer callers. */
  initial_password?: string | null;
}

export interface BookmarkResponse {
  id: number;
  page: number;
  note: string | null;
  createdAt: string;
}

export interface HistoryEntryResponse {
  id: number;
  comicId: number;
  comicTitle: string;
  action: string;
  page: number | null;
  timestamp: string;
}

export interface HistoryResponse {
  entries: HistoryEntryResponse[];
  totalCount: number;
}

export interface IngestErrorLogEntryResponse {
  ts: string;
  path: string;
  ext: string;
  errorClass: string;
  message: string;
}

export interface IngestErrorLogResponse {
  count: number;
  recent: IngestErrorLogEntryResponse[];
}
