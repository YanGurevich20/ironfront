# API v1 (Scaffold)

## POST /auth/exchange
Request:
- `provider`: `"dev" | "pgs"`
- `proof`: string
- `client.stage`: `"dev" | "prod"`

Response:
- `account_id`
- `session_token`
- `expires_at_unix`
- `is_new_account`
- `profile`: `{ username, display_name }`

## GET /me
- Requires `Authorization: Bearer <session_token>`.
- Returns authoritative profile payload.
