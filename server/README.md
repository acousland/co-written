# Optional AI server

The macOS app is fully useful offline. The app also supports direct OpenAI access with each user's own key and needs no separate server. This optional alternative lets an owner fund other users' contextual writing advice while keeping the owner's OpenAI API key away from downloads and public source. It is an invite-only starting point, not a public anonymous proxy.

## Deploy on a server you control

1. Copy `server/.env.example` to `server/.env` **on the server**. Fill in a dedicated project API key and an available Responses model supporting strict Structured Outputs. `OPENAI_MODEL` has no default so the service cannot start with an accidentally chosen model. Configure a small `GLOBAL_DAILY_LIMIT` initially; 500 is a sample ceiling, not a cost estimate.
2. Keep `.env` readable only by the deployment owner (`chmod 600 .env`). It is ignored by Git and excluded from the Docker image. Use your hosting platform's secret store when available.
3. Run `docker compose up -d --build` from `server/`. The service listens on `127.0.0.1:8080` on the host; its SQLite volume persists user hashes and quota counters. The container runs without root and has a read-only filesystem except its data volume and temporary directory.
4. Put a buffering HTTPS reverse proxy in front of it. Use a real domain and valid certificate, limit request bodies to 100 kB, and impose request/header timeouts and per-IP rate limits. Do not log Authorization headers, request bodies, or responses. Do not expose port 8080 publicly. Example Nginx location settings are in `nginx-location.conf`; place them inside your existing HTTPS server configuration.
5. Check `https://your-domain/health`. This checks the service process, not provider connectivity.
6. Issue a different token for each user, using the command below. Give the user your HTTPS origin and their token through your own private channel. There is deliberately no unauthenticated signup/token-minting API.

```sh
# Prints the new token once. Run on the server, outside public logs.
docker compose exec analysis python manage.py issue alice --daily-limit 20
# Immediate revocation of all tokens issued under this label
docker compose exec analysis python manage.py revoke alice
```

Choose **A shared Co-written service** in Settings, then enter the HTTPS origin (e.g. `https://writing.example.com`, with no path) and token. Saving the token permits AI for future explicitly requested analyses when AI is enabled; setup never sends the existing passage. Disable that toggle to use one-off confirmed requests. Use a personal token in this mode; keep the owner’s provider key on the server and out of client apps, GitHub, and issues.

## Boundaries

- Only `POST /v1/analyze` with a JSON object containing `text` is accepted. The client cannot choose a model, system prompt, destination, tools, token limit, or arbitrary API endpoint.
- Maximum 20,000 characters / 100,000 request bytes, 4,096 output tokens, a 65-second upstream timeout, and bounded upstream responses.
- Each token has a daily allowance and five requests per UTC minute. All users share a global daily request cap. SQLite `BEGIN IMMEDIATE` reserves all three counters before the API call, across worker processes. Failed calls remain charged so retries cannot avoid caps. Quotas survive restarts; deleting the database or deploying separate databases resets/splits their limits. Use one shared durable database for this deployment.
- Daily buckets reset at UTC midnight. The default cap bounds request count, not exact dollars. Cost depends on the model and tokenisation. Start with a low cap and configure provider project limits/alerts and operational monitoring for your budget.
- Token hashes, owner labels, and aggregate counters are stored; raw tokens, passages, results, and provider keys are not. Tokens have 256 random bits and can be revoked individually by label. Reusing a label groups its tokens for revocation.
- No web signup, payment system, password reset, browser CORS support, or user identity verification is included. For a public self-service product, add authenticated accounts and entitlement checks rather than distributing a universal token. Device identity or code signing cannot protect a shared client secret.
- Text is untrusted model input. Developer instructions constrain coaching and a strict JSON schema constrains output. The server validates excerpt evidence against the passage, including the Humanizer-based style review. The pinned 26-pattern catalogue is shared with the app; neither review path establishes authorship. Prompt injection can still affect advice quality; the model has no tools, credentials in its prompt, or authority to change configuration.
- `store: false` disables Responses application-state storage. It does not promise zero retention: provider abuse monitoring and other applicable data controls still apply. Read [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data) and disclose your hosting provider's logging and backups to users.

## Test without an API key

From the repository root:

```sh
PYTHONPATH=server python3 -W error::ResourceWarning -m unittest discover -s server/tests -v
python3 -m venv .venv
.venv/bin/pip install -r server/requirements.txt
.venv/bin/python server/tests/smoke_http.py
```

These tests mock the provider and exercise the Responses payload, output validation, real HTTP serving, auth, revocation, privacy, and concurrent quota reservations. A live model call still needs your server key and chosen model. Docker deployment needs a running Docker daemon.

AI replies use bounded concise fields. Invalid quoted findings are omitted with a visible note; useful summaries remain available. Incomplete, cutoff, filtered and refused replies return fixed error codes without forwarding private provider text. The supplied proxy waits 80 seconds and Gunicorn workers allow 90 seconds; the Mac client waits 75 seconds.
