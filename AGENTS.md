# AGENTS.md - ExtractPro (Castle Game Engine)

## Project Overview
Multi-component Castle Game Engine project in Object Pascal (Free Pascal/Lazarus):
- **Extract/** - Client game application (GUI)
- **logic/** - Shared logic library (`extractlogic.lpk`)
- **headless_app/** - Dedicated server (headless)
- **test/** - fpcunit unit tests

## Build Commands

### Client (Extract/)
```bash
cd Extract
castle-engine compile          # CGE CLI build tool
# Or open Extract_standalone.lpi in Lazarus
# Or open Extract_standalone.dproj in Delphi
```

### Server (headless_app/)
```bash
cd headless_app
castle-engine compile                                 # headless (default)
castle-engine compile --compiler-option=-dVISUAL      # окно + физика (тест)
# Or: lazbuild physics_headless_test.lpi --ws=none
# Or: lazbuild --bm=VisualDebug physics_headless_test.lpi --ws=none
```

### Logic Package (logic/)
```bash
cd logic
lazbuild extractlogic.lpk      # Compile package
```

### Run Tests (test/)
```bash
cd test
lazbuild fpcunitproject1.lpi   # Build test runner
./fpcunitproject1              # Execute tests
```

## Key Dependencies (external paths)
- Castle Engine 7.0-alpha.3: `/home/vano/Engines/castle-engine-7.0-alpha.3/`
- mORMot2: `/home/vano/fpcupdeluxe/custom_libraries/mORMot2/`
- Other packages registered in `packagefiles.xml`

## Project Structure Conventions
- Search paths in `CastleEngineManifest.xml` define module locations
- `../logic/src/` is shared by both client and server
- `castle-engine-output/` is build artifact directory (gitignored)
- `*.res`, `*.lps`, `backup/`, `*.db` are gitignored
- **Design files** (`*.castle-user-interface`) are loaded at runtime — no recompile needed after edits

## Testing
- Tests use fpcunit framework
- Test file: `test/TestCase1.pas` (RPC tests)
- Run via Lazarus or CLI as shown above

## Architecture: Loose Coupling via EventBus

### Principle
Systems must be **loosely coupled** — no direct references between systems or from views to system callbacks. Communication happens through **EventBus** (pub/sub).

### Two EventBus Layers

| Layer | Unit | Location | Purpose |
|-------|------|----------|---------|
| **Base** | `EventBus.pas` | `logic/src/` | Core game events (damage, death, extraction, etc.) — shared by client and server |
| **Client** | `ClientEventBus.pas` | `Extract/code/` | Client-only events (matchmaking state, UI, etc.) — `GlobalClientEventBus: TClientEventBus` singleton via lazy init |

### Lazy Singleton Pattern (no initialization/finalization)
```pascal
function GlobalClientEventBus: TClientEventBus;
```
Creates on first call, never freed (OS reclaims on exit). Avoids AV from module finalization order in FPC.

### Communication Flow
```
Publisher ──Queue+Flush──→ EventBus ──Subscribe──→ Consumer(s)
```
- Publishers call `GlobalClientEventBus.Queue(E); GlobalClientEventBus.Flush;`
- Consumers subscribe in `Start`, unsubscribe in `Stop`
- Event types and consumers are fully decoupled — publisher doesn't know who listens

### Current Client Events (`TClientGameEventType`)
| Event | Published By | Consumed By | Payload (`Amount`) |
|-------|-------------|-------------|-------------------|
| `cgeMatchmakingStateChanged` | `TClientMatchmakingSystem.Enqueue/Dequeue` | `TViewLobby` (show/hide SearchDesign), `TViewPlay` (SEARCH/CANCEL btn) | `1.0` = searching, `0.0` = idle |

### Adding a New Client Event
1. Add value to `TClientGameEventType` in `ClientEventBus.pas`
2. Fill `TClientGameEvent` record (use `Amount: Single` for simple state, `Data: Pointer` for payload)
3. Publish via `GlobalClientEventBus.Queue(E); GlobalClientEventBus.Flush;`
4. Subscribe via `GlobalClientEventBus.Subscribe(cgeYourEvent, @YourHandler);`

## Development Notes
- Uses `{$mode objfpc}{$H+}` and modern Pascal features (anonymous functions, function references)
- mORMot2 for database/ORM/networking — `TGameDatabase` (DbCore) wraps `TRestServerDB` with `TOSLock` for thread-safe concurrent access from lobby thread pool
- Physics simulation on server (headless)
- Client-server architecture with custom RPC (NetMessages, NetServer, NetClient)
- `TWorldSystemList = specialize TList<IWorldSystem>` defined in `Interfaces.pas`; `FSystems` uses `TList` instead of dynamic array in both `TGameWorld` and `TLobbyWorldBase`
- `TClientAuthSystem` is `class(TInterfacedObject, IWorldSystem)` — no dependency on `TGameWorld`; shared by both `GameWorldClient` and `LobbyClient`
- `TServerDbSystem` created once in `LobbyManager.SetDatabase` and shared across all raid lobbies + matchmaking lobby (single `TGameDatabase` instance with `TOSLock`)
- All lobby updates run in `TParallel.For` — each lobby's `Update` on a thread pool thread; `TGameDatabase` synchronous methods protected by `TOSLock`; async batched writes (`TRestBatchLocked`) thread-safe internally
- `TLobbyClient` (`LobbyClient.pas`) is the central lobby module — connects to matchmaking (port 7776), manages room list, trading, chat
- `TLobbyClientNetSystem` wraps `TGameClient` for ENET connection to matchmaking server

## RNL / ENET Connection Flow
- `TGameClient.Service` handles `RNL_HOST_EVENT_TYPE_PEER_APPROVAL` (type=5) as connection established (alongside `PEER_CONNECT`)
- `RNL_HOST_EVENT_TYPE_PEER_DENIAL` (type=6) handled as disconnect (alongside `PEER_DISCONNECT`)
- Client receives `PEER_APPROVAL` from server after handshake completes (not `PEER_CONNECT`)
- Server's `TGameServer.Service` does NOT handle `PEER_CHECK_CONNECTION_TOKEN` — RNL auto-accepts by default
- `TGameClient` reuses `FHost` with `AllowIncomingConnections := False` (outgoing client only)

## Auth Flow (msgAuth)
- `TClientAuthSystem.LoginAsync` → HTTP POST to auth server → stores `FToken`
- On ENET connect (`HandleConnected`/`OnClientConnected`), client packs `TAuthPayload` from `AuthToken` and sends `msgAuth` (msgType=15)
- Server validates via `IAuthValidator.ValidateToken` → `TAuthServerValidator` → synchronous SQLite query (`sessions` JOIN `users`)
- **`FRequireAuth=False`** by default: player added to `Players` immediately, no token needed
- **`--require-auth`**: all lobbies (matchmaking + game worlds) require `msgAuth` validation
- `TLobbyServer.RequireAuth` → `TLobbyNetSystem.RequireAuth` (getter/setter)
- Game world client (`TViewMain.Start`): token from `FAuthSystem.OnAuthResult` (login path). Direct `ViewMain` without login → **only works with `--require-auth=False`**
- Validation is synchronous (local SQLite). For remote DB — convert to async with `TTask.Run` + `TThreadedQueue`
- **Known limitation:** guest/anonymous login not implemented yet

## Yggdrasil IPv6 Support (branch `yggdrasil-ipv6`)

**Branch:** `yggdrasil-ipv6` — рабочая реализация IPv6 + Yggdrasil. Все изменения изолированы, при необходимости мёржатся в `master`.

### Проблема
mORMot2 использует `gethostbyname` (IPv4-only) для разрешения адресов (`mormot.net.sock.posix.inc:470`). Bare numeric IPv6 (`::1`, `201:9dea:...`) не парсятся → `ENetSock`.

### Решение: `THttpAuthSocket` в `AuthClient.pas`
- Собственный `THttpAuthSocket = class(THttpClientSocket)` с методом `OpenHost`
- Использует `getaddrinfo(AI_NUMERICHOST)` из libc напрямую (парсит и IPv4, и IPv6)
- Создаёт сокет через `c_socket`/`c_connect`/`c_close` (libc на Linux, ws2_32.dll на Windows)
- `fSock := TNetSocket(PtrInt(FD))` — mORMot2 хранит хендл как указатель
- mORMot2 не патчится, всё в нашем коде

### `GameConfig.pas`
Добавлены поля:
- `ServerHost: string` — Yggdrasil IP по умолчанию (`201:9dea:3336:fed6:3c78:fdf0:ccda:bf70`)
- `AuthPort: Word` — порт auth-сервера (`AUTH_SERVER_DEFAULT_PORT`)

### `TAuthClient`
- Конструктор: `TAuthClient.Create(const AHost: string; APort: Word)` (вместо URL)
- Параметры: `FHost`, `FPort: Word`
- `ClientAuthSystem.pas` передаёт `GlobalConfig.ServerHost`, `GlobalConfig.AuthPort`

### Изменённые файлы (ветка `yggdrasil-ipv6`)
| Файл | Что |
|------|-----|
| `logic/src/auth_server/AuthClient.pas` | `THttpAuthSocket` + `getaddrinfo`, кроссплатформенные импорты libc/ws2_32 |
| `logic/src/GameConfig.pas` | `ServerHost`, `AuthPort` поля |
| `Extract/code/systems/ClientAuthSystem.pas` | Использует `GlobalConfig` |
| `Extract/code/views/startview.pas` | `'::1'` → `GlobalConfig.ServerHost` |
| `Extract/code/views/gameviewlobby.pas` | `'::1'` → `GlobalConfig.ServerHost` |

### Cross-platform импорты (`AuthClient.pas`)
| Платформа | Функции | Библиотека |
|-----------|---------|------------|
| Linux/Android/macOS | `socket`, `connect`, `close`, `getaddrinfo`, `freeaddrinfo`, `gai_strerror` | `external 'c'` (libc/Bionic) |
| Windows | `socket`, `connect`, `closesocket`, `getaddrinfo`, `freeaddrinfo`, `gai_strerror` | `external 'ws2_32.dll'` (Winsock2) |

### Android APK сборка
- В `CastleEngineManifest.xml` добавлен `<service name="client_server" />` (даёт `INTERNET` + `ACCESS_NETWORK_STATE`)
- `android:usesCleartextTraffic="true"` — патчится вручную в `AndroidManifest.xml` после `castle-engine package`:

```bash
cd Extract
castle-engine package --os=android --cpu=aarch64 --mode=debug
sed -i 's|<application|<application android:usesCleartextTraffic="true"|' \
  castle-engine-output/android/project/app/src/main/AndroidManifest.xml
cd castle-engine-output/android/project
ANDROID_HOME=/home/vano/Android/Sdk JAVA_HOME=/usr/lib/jvm/java-17-openjdk \
  ./gradlew assembleDebug
cp app/build/outputs/apk/debug/app-debug.apk ../../../Extract-0.1-android-debug.apk
```

### ENET (RNL) — `TGameClient.Connect`
Уже корректно обрабатывает IPv6: оборачивает адрес в `[]` при наличии `:` (`NetClient.pas:123`).

## Common Tasks
| Task | Command |
|------|---------|
| Build client | `cd Extract && castle-engine compile` |
| Build server | `cd headless_app && castle-engine compile` |
| Build logic pkg | `cd logic && lazbuild extractlogic.lpk` |
| Run tests | `cd test && lazbuild fpcunitproject1.lpi && ./fpcunitproject1` |
| Open in Lazarus | Open `Extract/Extract_standalone.lpi` or `headless_app/physics_headless_test.dpr` |
| Build Android APK (yggdrasil-ipv6) | См. раздел "Android APK сборка" выше |