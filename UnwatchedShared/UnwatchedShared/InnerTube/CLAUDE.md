# InnerTube Core — see the main guide

`Core/` is the SmartTubeIOS API layer, mirrored from upstream and adapted for Unwatched. It lives
in the shared framework because three targets need it: the iPhone/iPad player, tvOS (which has no
WKWebView and so drives `InnerTubeAPI` directly), and the app's search.

**Before changing anything here, read `Unwatched/Unwatched/InnerTube/CLAUDE.md`** — the upstream
sync procedure, the per-file adaptations to re-apply on every sync, and the design constraints all
live there. Two that bite immediately:

- Keep these files as close to upstream as possible; Unwatched-specific logic belongs in the
  app-target files or in a separate `InnerTube/…` extension file outside `Core/`.
- Upstream's `package` modifiers become `public` here, not internal — the app target reads these
  declarations across the module boundary.
