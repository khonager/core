# Core app decisions

- Product: a curated personal app/website library with GitHub build monitoring
  and direct Android release downloads.
- Repository: lives alongside Core principles, documentation, and templates.
- Primary flow: search/select project → choose stable/dev release → download →
  Android confirmation → installed version; or inspect build → copy log/open GitHub.
- Target: Android first; web preview for design review. Other native targets later.
- Data: GitHub API + bundled curated catalog, local cache/preferences. Optional
  GitHub token for restricted logs, secure on Android and memory-only on web.
- User's visual direction: warm beige/eggshell/yellow canvas, large rounded-square
  icons, bold names, smaller muted descriptions, search above a simple list.
- Navigation: Library → Project details. Releases and activity are inline.
  Wide layout uses a library/detail split. No separate Settings or Activity page.
- Build separator: red failure, orange active, green success; neutral unknown.
  Blue during download/install; measured transfer progress, indeterminate installer.
- Notification bell: project-specific switches in a sheet; no backend. V1 delivers
  alerts on refresh/open only, disclosed within the sheet.
- Explicit exclusions: ratings, sign-up, backend, Sandbox/Gallery in v1.
- Theme: intentionally single light theme, following the user's design.
- Shared UI extraction: deferred until a real second consumer exists.
- Release identity: development-only package/signing; stable release needs its own key.
