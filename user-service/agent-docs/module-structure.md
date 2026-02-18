# Module Structure

- `src/index.ts`: HTTP server bootstrap.
- `src/routes/`: HTTP route handlers.
- `src/auth/`: session/auth primitives.
- Keep persistence adapter behind a boundary so in-memory store can be replaced with Cloud SQL.
