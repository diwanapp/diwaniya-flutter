# Diwaniya Flutter App Operating Instructions

## Project Context
- This is the independent Flutter mobile app repository for Diwaniya.
- Core stack: Flutter/Dart, go_router, Hive, flutter_secure_storage, local_auth, image/file picking, audio utilities, and the existing API client layer.
- The app is Arabic-first, RTL-first, and mobile-first. User-facing Arabic must say "الإدارة", never "المالك".

## Commands Discovered
- Install dependencies: `flutter pub get`
- Static analysis: `flutter analyze`
- Tests: `flutter test`
- Run locally with configured API: `flutter run --dart-define=API_BASE_URL=<url>`
- Release builds must use an HTTPS API endpoint, not localhost, private IPs, or cleartext transport.

## Required Governance Reading
- Before consequential mobile changes, read the relevant files under `docs/governance/`.
- Use `mobile-release-quality-checklist.md` before changing authentication, session handling, API configuration, network logging, offline cache, protected screens, marketplace ads, payments, receipts, privacy, or release behavior.
- Trivial copy-only, comment-only, or isolated styling changes do not need every document; choose governance reading by risk and affected surface.

## Risk Classification and Approval Gates
- Low risk: copy, styling, isolated presentation, or documentation changes with no auth, data, privacy, financial, or lifecycle implication.
- Medium risk: behavior changes, standard APIs, non-sensitive UI workflows, or refactors with bounded blast radius.
- High risk: payments, receipts, publication, authentication, authorization, privacy, deletion, subscriptions, file uploads, role-sensitive screens, public visibility, audit behavior, secure storage, or release networking.
- Critical risk: secrets, production data, payment providers, public exposure, irreversible data operations, legal retention/deletion actions, or changes that could expose private data broadly.
- High and Critical changes require a written plan before implementation.
- High and Critical changes require explicit acceptance criteria, tests, rollback notes, and security/audit review.
- Critical changes require explicit user approval before any state-changing implementation begins.
- Low-risk changes should stay efficient and should not be burdened by unnecessary process.

## Git, Worktree, and Change Control
- Run `git status --short` before and after work.
- Inspect existing diffs before changing files.
- Do not overwrite or discard unrelated user changes.
- Use an isolated branch or worktree for High-risk or multi-file feature work.
- Do not work directly on `main` or `master` for High-risk changes unless the user explicitly approves.
- Keep one logical feature or fix per commit.
- Review `git diff --check` and the staged diff before a commit.
- Do not use `git reset --hard`, `git clean -fd`, force-push, destructive rebase, or history rewriting without explicit approval.
- Do not commit generated private artifacts, backups, secrets, screenshots containing private data, or temporary scripts unless explicitly intended.
- Never commit until requested checks pass and the user has an opportunity to review meaningful changes.

## API and Networking Rules
- Use existing `ApiClient`, `Endpoints`, and token storage patterns.
- Do not hardcode secrets, API tokens, admin credentials, payment credentials, or private endpoints in Dart.
- Network logging must remain disabled by default and must redact sensitive data when intentionally enabled for development.
- Protected API calls must rely on backend authentication and server-side authorization; UI gating is not enough.
- Release debug flags, cleartext networking, private IP base URLs, and network-body logging must be explicitly blocked or fail closed in release mode.

## Session and Token Handling
- Store access and refresh tokens only through the established secure storage path.
- Do not move tokens to logs, screenshots, shared preferences, query strings, or browser-like storage.
- Authentication, refresh, logout, and account/privacy flows require tests when changed.
- Offline cache must not preserve sensitive receipt, payment, admin, token, or private user data beyond an approved policy.

## UX Rules
- Preserve approved app visuals unless a deliberate design decision is documented.
- Keep Arabic text, layout direction, navigation, forms, empty states, and error states RTL-first.
- Payment, receipt, publication, deletion, subscription, privacy, and access-control screens must use structured flows, not prompt-style shortcuts.
- Do not fabricate analytics, marketplace ad metrics, payment status, or operational data.

## Merchant Ads and Marketplace
- Public ads shown in the app must come from backend-approved lifecycle eligibility.
- Review approval, payment verification, placement configuration, and publication are separate concepts.
- Mobile visibility is always driven by backend eligibility and server response contracts.
- The app must not locally infer publication eligibility from placement, image URL, payment status, schedule, or cached data.

## Security and Privacy
- Saudi PDPL/privacy-sensitive data must be minimized in local storage and logs.
- Receipts, payment evidence, phone numbers, tokens, invitations, and private Diwaniya data are sensitive.
- Manual override, publication, payment verification, deletion, subscription, privacy, and access-control decisions belong on the backend with audit logs.

## Required Checks Before Commit
- `flutter analyze`
- `flutter test` for behavior changes
- Manual release-safety review for API base URL, network logging, and cleartext transport behavior

## Forbidden Actions
- Do not commit secrets or production data.
- Do not bypass backend lifecycle rules in Flutter.
- Do not add fake metrics or placeholder values that look real.
- Do not change approved visuals as a side effect of unrelated work.

## Definition of Done Summary
PASS only when the mobile change is Arabic/RTL-first, secure with tokens, backend-authorized, honest about metrics, lifecycle-safe for ads, analyzer-clean or intentionally documented, tested where behavior changes, and release-safe for HTTPS.
