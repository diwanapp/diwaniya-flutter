# Mobile Release Quality Checklist

## Governance Baseline
Apply `AGENTS.md` first. This checklist focuses on mobile release safety, privacy, token handling, and backend-owned visibility.

## Configuration and Build Safety
- [ ] Release API base URL is HTTPS and not localhost, private IP, or cleartext transport.
- [ ] Release debug flags fail closed or are explicitly blocked in release mode.
- [ ] Cleartext networking and private IP base URLs fail closed in release mode.
- [ ] Network-body logging is blocked in release mode.
- [ ] No secrets, API keys, admin tokens, payment credentials, receipt data, or private payloads are committed.
- [ ] Network logging is disabled by default and redacts sensitive data when enabled for development.
- [ ] Platform network security settings are reviewed for release behavior.

## Arabic and UX
- [ ] Arabic-first, RTL-first, mobile-first layout is preserved.
- [ ] User-facing Arabic says "الإدارة", never "المالك".
- [ ] Approved visuals are preserved unless a design decision says otherwise.
- [ ] Loading, empty, error, offline, permission, and success states are present for changed flows.

## Authentication and Privacy
- [ ] Tokens use the existing secure storage path.
- [ ] Protected data depends on backend authentication and server-side authorization.
- [ ] Saudi PDPL/privacy-sensitive data is minimized in local storage, logs, screenshots, and crash context.
- [ ] Offline cache cannot preserve sensitive receipt, payment, admin, token, or private user data beyond the approved policy.
- [ ] Deletion, privacy, subscription, payment, receipt, publication, and access-control flows are backend-authorized and auditable.

## Marketplace and Ads
- [ ] Public ads are rendered only from backend lifecycle eligibility.
- [ ] Review approval, payment verification, placement configuration, and publication are not conflated in UI state.
- [ ] Mobile visibility is driven by backend eligibility and server response contracts.
- [ ] Mobile does not locally infer publication eligibility from placement, image URL, payment status, schedule, or cached data.
- [ ] The app does not fabricate ad metrics, payment state, or operational analytics.
- [ ] Unavailable metrics are shown as unavailable or omitted.

## Validation
- [ ] `flutter analyze` passes or remaining findings are documented and unrelated.
- [ ] `flutter test` passes for changed behavior.
- [ ] Release smoke test covers launch, authentication/session state, protected API call, and marketplace ad rendering when affected.

## Pass/Fail Gate
PASS when the release is HTTPS-safe, token-safe, Arabic/RTL-safe, privacy-aware, backend-authorized, metric-honest, lifecycle-safe, and tested. FAIL if the app can expose protected data or infer ad publication locally.
