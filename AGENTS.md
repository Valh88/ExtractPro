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
castle-engine compile          # Uses physics_headless_test.dpr
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
- mORMot2 for database/ORM/networking
- Physics simulation on server (headless)
- Client-server architecture with custom RPC (NetMessages, NetServer, NetClient)

## Common Tasks
| Task | Command |
|------|---------|
| Build client | `cd Extract && castle-engine compile` |
| Build server | `cd headless_app && castle-engine compile` |
| Build logic pkg | `cd logic && lazbuild extractlogic.lpk` |
| Run tests | `cd test && lazbuild fpcunitproject1.lpi && ./fpcunitproject1` |
| Open in Lazarus | Open `Extract/Extract_standalone.lpi` or `headless_app/physics_headless_test.dpr` |