# AUDIT REPORT — Gym Retention & Management SaaS

**Date:** 2026-08-28
**Auditor:** Kilo (lead architect / senior engineer)
**Working directory:** `E:\Gym`
**Workspace root:** `E:\`

---

## 1. EXECUTIVE SUMMARY

The designated working directory **`E:\Gym` is empty**. There is **no existing gym
repository** present on disk. No `pubspec.yaml`, `lib/`, `test/`, `supabase/`,
`android/`, `ios/`, `web/`, `README.md`, or any source code exists inside
`E:\Gym`.

This is a **greenfield** engagement. Per the non-negotiable rules, the first
requirement is to "inspect the existing repository completely." That repository
does not exist at the working directory.

To satisfy the *spirit* of "reuse good existing code" (rule 3), the full
on-disk filesystem (`E:\`) was inventoried. Several unrelated prior projects
exist on sibling directories. They are catalogued below and a reusable pattern
assessment is provided. None is a gym application.

---

## 2. SIBLING REPOSITORIES ON DISK (UNRELATED)

| Path | Name / Purpose | Stack | Verdict for this engagement |
|------|----------------|-------|------------------------------|
| `E:\mindspace` | MindSpace — AI study assistant (PDF docs, Puter AI) | Flutter 3.44.7, Riverpod 2.x, GoRouter, Hive CE, flutter_secure_storage, pdfx, Stitch design, `flutter_test` + mockito (81 tests, 17 files, zero lint) | **Reusable patterns only** (architecture, design-system approach, testing conventions, CI). Domain = study assistant. Supabase was *removed* (migrated to Puter). |
| `E:\APP` | Syllabus Scanner — extracts exam dates from syllabi | React 18 + Vite + Tailwind, Node/Express backend, Supabase, Gemini, Nodemailer | Different stack; not Flutter. Not reusable as-is. |
| `E:\PROTOTYPE` | LodgeIQ — hotel/lodge management HTML prototype | Static HTML/CSS/JS, Tailwind, mock JS data | Closest *domain* analogy (multi-tenant owner/staff/guest portals, dashboard, check-in, payments, reports, notifications). But static prototype, no backend. |
| `E:\real\LodgeIQ` | LodgeIQ — Django hospitality SaaS | Python/Django backend, React frontend, `.venv`, `apps/config/tests` | Multi-tenant SaaS with auth/roles/dashboard. Domain close (owner→staff→guest ≈ owner→front-desk→member). But Django/React, not Flutter. |
| `E:\COOK\app` | cooksmart — Flutter boilerplate ("A new Flutter project") | Flutter, google_fonts, http, shared_preferences, uuid, intl, image_picker, flutter_dotenv | Empty boilerplate. Not usable. |

### What MindSpace contributes (patterns to reuse)
- **Layering:** `lib/features/<feature>/{data,domain,presentation}/` (clean
  architecture / feature-first).
- **State:** `flutter_riverpod` (preferred) + `ChangeNotifier`/`StateProvider`
  for UI-only state.
- **Routing:** `go_router` with custom `pageTransitions`.
- **Error layer:** `core/errors/app_exception.dart` + `error_handler.dart`.
- **Widgets:** `app_button.dart`, `app_text_field.dart`, `app_error_widget.dart`,
  `empty_state.dart`, `loading_overlay.dart`.
- **Testing:** unit tests for entities + widget tests for screens + a service
  test pattern; `mockito` for mocking; CI runs `flutter analyze` + `flutter test`.
- **Design:** Stitch-derived tokens (typography, spacing, gold accent), neutral
  surfaces, subtle animations, custom transitions.
- **CI:** single GitHub Actions workflow (`.github/workflows/ci.yml`) building
  Android APK + iOS IPA + Web.

### Reuse constraints / non-negotiables
- MindSpace auth is **Puter token-based**, not Supabase. The gym SaaS requires
  Supabase Auth (rule 11: auth via Supabase). The auth module must be rebuilt;
  only the *pattern* (repository abstraction + auth_provider) is reusable.
- MindSpace has **no Supabase** anymore — no schema to inherit. Schema is
  greenfield from the product spec.
- MindSpace has **no Edge Functions** — backend is greenfield.
- The `app` (COOK) and `APP` projects are not Flutter+Supabase gym apps and are
  not reused.

---

## 3. TOOLCHAIN INVENTORY (VERIFIED)

| Tool | Version | Available | Notes |
|------|---------|-----------|-------|
| Flutter | 3.44.7 stable | ✅ | `sdk: ^3.12.2`, channel stable |
| Dart | 3.12.2 | ✅ | Bundled with Flutter |
| Node | v24.19.0 | ✅ | `npm` at `C:\nvm4w\nodejs` |
| npm | 11.17.0 | ✅ | |
| Supabase CLI | 2.115.0 | ✅ | `supabase functions`, `supabase db`, `supabase start` |
| Playwright | 1.62.1 | ✅ via `npx playwright` | Browsers not yet installed |
| Git | 2.55.0 | ✅ | |
| Docker | — | ❌ | **Not installed.** `supabase start` (local Postgres) cannot run. |
| psql / Postgres client | — | ❌ | Cannot execute SQL locally against live Postgres — **replaced by PGLite in-memory engine (see below).** |
| tsc (TypeScript) | — | ❌ globally | `npx tsc` after local `npm i -D typescript`. |
| Java / Android SDK | — | ❌ | `java` not found. Android/iOS *device* builds not verifiable locally. Web build OK. |

### Verification strategy this engagement
Docker/Java/Postgres-client are unavailable, but an in-memory PostgreSQL is:

- **SQL migrations + RLS/constraints** — loaded into **in-memory PostgreSQL via
  `@electric-sql/pglite`** (npm, no server, no Docker). This *executes the
  actual migration files* and runs tenant-isolation + constraint assertions with
  a non-superuser role and session-scoped JWT claims (`auth.uid()` /
  `auth.gym_id()` shims), mirroring the real Supabase runtime. ✅ verifiable
  locally via `test/sql_db_test.js`.
- **Flutter app** — `flutter analyze` + `flutter test` (Dart unit/widget tests
  for business rules). ✅ verifiable.
- **TypeScript edge functions** — type-checked with `npx tsc --noEmit`.
  ✅ type-check verifiable; runtime execution requires a Supabase project.
- **Playwright** CLI 1.62.1 present; full browser run requires installing
  browsers + a served web build.
- **UNVERIFIED locally (require remote infra):** Android/iOS archive builds
  (no Java), full Playwright browser runs.

---

## 4. EXISTING FEATURES / CODE / DB / BACKEND / UI / DESIGNSYSTEM

- **Existing features:** none in `E:\Gym` (greenfield). MindSpace features are
  study-assistant features (auth, dashboard, document viewer, annotations, AI
  chat, summarization, flashcards, folders, settings) — **not** gym features.
- **Existing database:** none. No `supabase/` in `E:\Gym`. MindSpace uses Hive
  (local) + Puter KV — not Postgres.
- **Existing backend:** none. No Edge Functions. MindSpace backend was Puter.
- **Existing UI:** none in `E:\Gym`. MindSpace has a Stitch-based design system
  that serves as the *pattern* reference only.
- **Existing design system:** MindSpace `lib/config/theme.dart` +
  `lib/core/widgets/*` (pattern reference). Gym app will define its own
  tokens in `lib/core/theme/`.
- **Existing tests:** none in `E:\Gym`. MindSpace has 81 tests (pattern
  reference).
- **Existing CI/CD:** none in `E:\Gym`. MindSpace has one GitHub Actions
  workflow (pattern reference).
- **Existing documentation:** none in `E:\Gym`.

---

## 5. SECURITY SCAN OF DISK (EXISTING PROJECTS)

Quick sweep of sibling projects for anti-patterns relevant to this engagement:

- **MindSpace:** auth repository split between `puter_auth_repository.dart` and
  `mock_auth_repository.dart` — the *mock* repository exists in non-test source
  tree, a latent risk if shipped (rule 17). No Supabase service-role key in
  Flutter (good). `env.dart.example` present for dart-define config.
- **APP (backend):** `.env` exists alongside `.env.example` (risk if committed).
  `server.js` Express API — check for auth middleware.
- **PROTOTYPE / LodgeIQ:** static mock JS data (`mock-data.js`) drives UI
  (rule 17 violation risk for a demo, but it is a prototype).
- **COOK/app:** `pubspec.yaml` references `.env` as a Flutter asset
  (`assets: - .env`) — **anti-pattern**: env files bundled as assets are visible
  to end users. The gym project will NOT ship `.env` as an asset; config uses
  `--dart-define` only.

---

## 6. KNOWN BUGS / TECHNICAL DEBT / RISKS

1. **Empty working directory** — no baseline to diff against. Every file is new.
2. **Tooling gaps** — no Docker/Java/Postgres client limits local verification of
   the database layer and mobile builds.
3. **Playwright browsers** not installed — E2E tests must be written to a plan
   and run once browsers + a served web build exist.
4. **Payment provider not selected** — spec requires a provider webhook with
   idempotency. Defaulting to a provider-agnostic architecture with Stripe as
  the reference implementation (assumption, documented).
5. **Multi-tenant RLS** is the #1 correctness risk — everything else depends on
   `gym_id` isolation enforced in Postgres, not in Flutter.

---

## 7. MISSING REQUIREMENTS (vs. the 52-phase spec)

The spec is internally complete; the *implementation* is missing entirely
because the repo is greenfield. Nothing is "missing from the repo" — the repo
is absent. All phases 1–52 must be executed from scratch, reusing only
*architectural patterns* from `E:\mindspace`.

---

## 8. RECOMMENDED IMPLEMENTATION ORDER

Given the greenfield state and local-tooling constraints, the order prioritises
**verifiable correctness** of the foundation first:

1. **Audit (this file).** ✅
2. **Requirements** — `PRODUCT_REQUIREMENTS.md`, `ASSUMPTIONS.md`,
   `ARCHITECTURE.md`.
3. **Project skeleton** — `flutter create`, `supabase init`, git,
   `AGENTS.md`/`kilo.json`.
4. **Database** — migrations + RLS (pgTAP test file). *Highest correctness risk.*
5. **Business rules** (Dart) — centralised, with `flutter test`. *Verifiable.*
6. **Edge Functions** (TS) — privileged ops, idempotent, type-checked.
7. **Auth** — Supabase Auth + gym-scoped profiles; role resolution.
8. **Core features** — QR check-in, no-show scan, follow-up, renewal, payments,
   notifications, data-quality.
9. **Design system** — Stitch/Taste/Awesome tokens; reusable components.
10. **Flutter UI** — owner, front-desk, member screens (multi-tenant).
11. **Tests** — flutter unit (business rules), integration, Playwright E2E.
12. **Security / observability / CI-CD / docs / production checklist.**

The full 52-phase plan in the task brief is adopted verbatim as the execution
backbone; this report covers Phase 1.

---

## 9. AUDIT STATUS

| Area | Status |
|------|--------|
| Repository present at `E:\Gym` | ❌ EMPTY (greenfield) |
| Flutter toolchain | ✅ 3.44.7 |
| Supabase CLI | ✅ 2.115.0 |
| Docker (local Supabase DB) | ❌ not installed |
| Postgres client (psql) | ❌ not installed |
| Playwright | ✅ 1.62.1 (browsers TBD) |
| Java / Android SDK | ❌ not installed |
| Reused existing gym code | ❌ none exists |
| Reused architectural patterns | ✅ from `E:\mindspace` |
