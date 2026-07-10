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

## Testing
- Tests use fpcunit framework
- Test file: `test/TestCase1.pas` (RPC tests)
- Run via Lazarus or CLI as shown above

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

## Common Tasks
| Task | Command |
|------|---------|
| Build client | `cd Extract && castle-engine compile` |
| Build server | `cd headless_app && castle-engine compile` |
| Build logic pkg | `cd logic && lazbuild extractlogic.lpk` |
| Run tests | `cd test && lazbuild fpcunitproject1.lpi && ./fpcunitproject1` |
| Open in Lazarus | Open `Extract/Extract_standalone.lpi` or `headless_app/physics_headless_test.dpr` |