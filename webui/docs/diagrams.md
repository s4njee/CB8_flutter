# CB8 Flow Diagrams

These diagrams are intentionally small. They are here to help new contributors
build a mental model before diving into files.

## Renderer To API To Database

```mermaid
flowchart LR
  UI["React component\nsrc/renderer/components or pages"] --> API["renderer API helper\nsrc/renderer/lib/api/*.ts"]
  API --> HTTP["HTTP /api request"]
  HTTP --> Server["Fastify wrapper\nsrc/main/webServer/server.ts"]
  Server --> Route["Route handler\nsrc/main/webServer/routes/*.ts"]
  Route --> DB["LibraryDatabase facade\nsrc/main/libraryDatabase.ts"]
  DB --> Domain["DB domain module\nsrc/main/db/*.ts"]
  Domain --> SQLite["SQLite library.db"]
```

## Upload And Ingest

```mermaid
flowchart TD
  Admin["Admin UI\nUploadPanel/AddPathPanel"] --> UploadRoute["upload route\nroutes/upload.ts"]
  UploadRoute --> IngestBridge["webServer/ingest.ts"]
  IngestBridge --> Service["IngestService\nsrc/main/ingestService.ts"]
  Service --> Archive["Archive/page helpers\narchiveLoader, EPUB/PDF helpers"]
  Service --> Thumb["Thumbnail generation\nthumbnailGenerator.ts"]
  Service --> DB["Batch DB writes\nLibraryDatabase"]
  Service --> Errors["ingest_errors table\nsrc/main/db/ingestErrors.ts"]
  UploadRoute --> Stream["NDJSON progress events"]
  Stream --> Admin
```

## Reader Page/Image Flow

```mermaid
flowchart LR
  ReaderPage["ReaderPage.tsx"] --> FetchRecord["GET /api/comics/:id"]
  FetchRecord --> PickReader["ComicReader / EpubReader / PdfReader"]
  PickReader --> PageReq["Page or file request"]
  PageReq --> Routes["routes/comics.ts"]
  Routes --> Cache["archiveCache.ts"]
  Cache --> Loader["archiveLoader.ts"]
  Loader --> Resize["imageResizer.ts\noptional width cache"]
  Resize --> Browser["Rendered page"]
  PickReader --> Progress["PUT /api/comics/:id/progress"]
```
