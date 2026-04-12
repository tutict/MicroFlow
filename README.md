# MicroFlow

MicroFlow is a lightweight collaboration system scaffold with a GraalVM-oriented Spring Boot backend and a Flutter frontend.

## Layout

- `backend`: Spring Boot 3.5 Maven project targeting Java 21+ and GraalVM Native Image
- `frontend`: Flutter client scaffold for mobile, desktop, and web

## Backend quick start

```powershell
cd backend
./mvnw spring-boot:run
```

Default demo account:

- `demo@microflow.local`
- `demo12345`

Native build:

```powershell
cd backend
./mvnw -Pnative native:compile
```

## Frontend quick start

```powershell
cd frontend
flutter pub get
flutter run -d chrome
```

Optional runtime endpoints:

```powershell
flutter run -d chrome `
  --dart-define=MICROFLOW_API_BASE_URL=http://localhost:8080/api/v1 `
  --dart-define=MICROFLOW_WS_BASE_URL=ws://localhost:8080/ws
```

## Pairing flow

When the backend starts, it now logs a one-time pairing code similar to:

```text
MicroFlow pairing code for instance 'microflow' is ABCD-7KQ2
```

If you can access the backend host locally, you can also open the local pairing console on that machine:

```text
GET /api/v1/bootstrap/console
GET /api/v1/bootstrap/challenge
GET /api/v1/bootstrap/qr
```

These three endpoints are restricted to loopback access on the backend machine. They are intended for local install or deployment setup, not for public exposure.

Connect the frontend in this order:

1. Start the backend and read the pairing code from the backend terminal or service log.
2. If you are on the backend machine, you can open `/api/v1/bootstrap/console` to see the current code and QR payload.
3. Open the frontend app. It will show the connect page before sign-in.
4. Enter the backend server URL such as `http://localhost:8080`, `http://192.168.x.x:8080`, or your deployed host.
5. Enter the pairing code.
6. After a successful handshake, the backend returns the runtime `serverOrigin`, `apiBaseUrl`, and `wsBaseUrl`.
7. The frontend stores those runtime endpoints locally, then continues to the sign-in page.

This allows the frontend and backend to be deployed separately. The frontend only needs the backend origin plus the one-time pairing code; after pairing, it uses the backend-provided API and WebSocket addresses.

After sign-in, the frontend workspace top bar now exposes an Agent diagnostics entry. It opens a diagnostics page backed by:

```text
GET /api/v1/agent-diagnostics?workspaceId=...
```

The diagnostics view shows each configured agent's provider, endpoint, credential presence, and latest connectivity probe result.

Pairing endpoint:

```text
POST /api/v1/bootstrap/pair
```

## Backend capabilities

- Java 21+, Spring MVC, WebSocket, and Virtual Threads
- SQLite-backed auth, workspace, message, and agent-run storage
- JWT login/register flow with a lightweight custom filter
- AES-GCM encrypted message persistence
- `@agent` detection with asynchronous mock agent execution on virtual threads
- WebSocket channel subscription and realtime broadcast
- Deployment-aware agent catalog discovery from `./data/agents.json`, env vars, or inline JSON

## Deployment agent config

The backend now loads machine-local agent definitions in this order:

1. `MICROFLOW_AGENT_CONFIG_JSON`
2. `MICROFLOW_AGENT_CONFIG_PATH` (default: `./data/agents.json`)
3. Spring property list `microflow.agent.providers`
4. `OPENCLAW_ENDPOINT_URL` plus `OPENCLAW_AGENT_KEYS`
5. fallback `mock-openclaw`

Example `data/agents.json`:

```json
{
  "providers": [
    {
      "provider": "openclaw",
      "endpointUrl": "http://127.0.0.1:8787",
      "credential": "local-dev-token",
      "agentKeys": ["assistant", "reviewer"]
    },
    {
      "provider": "codeclaw",
      "endpointUrl": "http://127.0.0.1:8790",
      "agentKeys": ["architect"]
    }
  ]
}
```

Shortcut env-based setup:

```powershell
$env:OPENCLAW_ENDPOINT_URL="http://127.0.0.1:8787"
$env:OPENCLAW_AGENT_KEYS="assistant,reviewer"
```

## Example endpoints

- `GET /api/v1/system/health`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/workspaces`
- `GET /api/v1/workspaces/{workspaceId}/channels`
- `GET /api/v1/channels/{channelId}/messages`
- `POST /api/v1/channels/{channelId}/messages`
- `GET /api/v1/agents?workspaceId=...`
- `GET /api/v1/agent-runs?workspaceId=...`

## WebSocket

Connect to:

```text
ws://localhost:8080/ws?token=<jwt>
```

Client events:

```json
{"type":"SUBSCRIBE","payload":{"channelId":"<channel-id>"}}
{"type":"CHAT_SEND","channelId":"<channel-id>","payload":{"workspaceId":"<workspace-id>","content":"@assistant summarize this"}}
```
