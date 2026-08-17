# Codex Guardrails

## General
- Do not connect to production or staging servers unless the user explicitly asks.
- Do not send real requests to PayTR, Faturaport, Netgsm, or other external services unless explicitly approved.
- Do not run migrations or mutate data on a real database without explicit approval.
- Do not commit `.env`, secrets, credentials, API keys, certificates, or private config values.
- Do not silently change production or staging configuration values.
- Do not break the existing individual/B2C flow while changing B2B behavior.
- Do not run `git commit`, `git push`, `git merge`, `git rebase`, or switch branches unless explicitly asked.
- If dependency or package version changes are needed, explain the reason and wait for approval.
- Before saying work is complete, run relevant tests and report results. If tests cannot be run, say so; do not assume PASS.
- At the end of each task, check and report `git diff` and `git status`.

## B2B Business Rules
- A candidate arriving through a B2B corporate invitation must never pay individually.
- Corporate credit must be consumed only by backend settlement after a positive/shareable result; Flutter must not invent local credit state.
- OTP, incomplete applications, upload failures, or negative evaluations must not trigger payment or credit consumption UI.
- Duplicate callback, worker retry, repeated settlement, or completed invitation reuse must not lead to duplicate user actions that imply duplicate credit or invoice effects.
- Preserve FEFO, package expiration, idempotency, and concurrency assumptions exposed by backend APIs.
- Corporate users may see only their own organization's applications and the Kiralayabilir Miyim result report.
- Do not add UI that exposes raw Findeks PDF, OCR output, or raw financial data to corporate users.
- Preserve candidate organization-specific consent and share authorization.
- After consent revoke, future corporate access must be closed in the UI as well as the backend.
- Invoice failure must not block successful payment or active credit use in user messaging.
- Do not create flows that could cause duplicate invoices.

## SMS / OTP Standard
- Use Android SMS Retriever for eligible OTP flows; do not request broad SMS read permissions.
- Use iOS `AutofillHints.oneTimeCode` and domain-bound AutoFill where applicable.
- Manual OTP entry must always remain available.
- Auto-submit behavior should stay consistent with the individual OTP flow where appropriate.
- When adding or changing an OTP screen or flow, verify Android and iOS automation coverage.
- OTP coverage must be considered for individual login, corporate activation, first owner activation, corporate login, password reset, new member activation, and B2B candidate applications.

## Flutter Rules
- Do not regress the existing individual flow or current individual OTP behavior.
- B2B phone fields must display a fixed `+90` prefix and accept exactly 10 user-entered digits in `5XXXXXXXXX` format (no leading 0). Normalize pasted `05XXXXXXXXX`, `905XXXXXXXXX`, or `+905XXXXXXXXX` values to backend format `+905XXXXXXXXX` where safe.
- Do not show raw backend enum names, error codes, or technical exception text directly to end users.
- B2B user-facing copy must be Turkish with correct Turkish characters.
- Do not add corporate UI access to the raw Findeks report.
- When changing deep links, App Links, or Universal Links, keep the existing custom scheme fallback working.
- If Android or iOS native configuration changes are made, report the effect explicitly.
- For Flutter screen changes, add or improve widget/integration tests when practical.
