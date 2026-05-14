{
  GameServerApp.pas — головной цикл headless-сервера ExtractPro.

  Выносит логику main-блока .dpr в отдельный класс,
  чтобы сервер можно было переиспользовать и настраивать
  без правки точки входа.

  ⚠ Не использует CastleTransform/CastleScene — чистый сервер
    без OpenGL-зависимостей. Физика опциональна через WorldBridge
    в визуальном режиме.

  ── Использование ───────────────────────────────────────────────────
    ServerApp := TGameServerApp.Create;
    ServerApp.ParseArgs;
    ServerApp.Run;
    ServerApp.Free;

  ── Команды ─────────────────────────────────────────────────────────
    --port=N           порт (по умолчанию 7777)
    --max-players=N    макс игроков (по умолчанию 8)

  ── Зависимости ────────────────────────────────────────────────────
    SysUtils, NetServer, GameWorld, WorldBridge
}
unit GameServerApp;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  help_types, Interfaces, WorldTypes, GameWorld, GameConfig,
  NetServer, NetMessages;

type
  TTickEvent = procedure(Sender: TObject; const SecondsPassed: Single) of object;
  TLogEvent = procedure(Sender: TObject; const Msg: String) of object;

  TGameServerApp = class
  private
    FServer: TGameServer;
    FPort: Word;
    FMaxPlayers: Integer;
    FRunning: Boolean;
    FTickCount: Int64;
    FOnTick: TTickEvent;
    FOnLog: TLogEvent;
    procedure Log(const Msg: String);
  public
    constructor Create;
    destructor Destroy; override;
    procedure ParseArgs;
    procedure Run;
    procedure Stop;
    class procedure RunApp;
    property Server: TGameServer read FServer;
    property Port: Word read FPort write FPort;
    property MaxPlayers: Integer read FMaxPlayers write FMaxPlayers;
    property Running: Boolean read FRunning;
    property OnTick: TTickEvent read FOnTick write FOnTick;
    property OnLog: TLogEvent read FOnLog write FOnLog;
  end;

var
  ServerApp: TGameServerApp;

implementation

{ TGameServerApp }

constructor TGameServerApp.Create;
begin
  inherited Create;
  FPort := 7777;
  FMaxPlayers := 8;
  FRunning := False;
  FTickCount := 0;
end;

destructor TGameServerApp.Destroy;
begin
  Stop;
  inherited;
end;

procedure TGameServerApp.Log(const Msg: String);
begin
  if Assigned(FOnLog) then
    FOnLog(Self, Msg)
  else
  begin
    WriteLn(Msg);
    Flush(Output);
  end;
end;

procedure TGameServerApp.ParseArgs;
var
  S: String;
  i: Integer;
begin
  for i := 1 to ParamCount do
  begin
    S := ParamStr(i);
    if S.StartsWith('--port=') then
      FPort := Word(StrToIntDef(S.SubString(7), 7777))
    else if S.StartsWith('--max-players=') then
      FMaxPlayers := StrToIntDef(S.SubString(14), 8);
  end;
end;

procedure TGameServerApp.Run;
const
  DT = 1 / 60;
begin
  if FRunning then Exit;
  FRunning := True;

  FServer := TGameServer.Create(FPort, FMaxPlayers);
  FServer.Start;

  Log(Format('ExtractPro Server starting on port %d (max %d players)',
    [FPort, FMaxPlayers]));
  Log('Server running. Press Ctrl+C to stop.');

  try
    while FRunning do
    begin
      FServer.Service(0);

      if Assigned(FOnTick) then
        FOnTick(Self, DT);

      Inc(FTickCount);
      if (FTickCount mod 3600) = 0 then
        Log(Format('[%d] Players: %d', [FTickCount div 60, FServer.Peers]));

      Sleep(Round(DT * 1000));
    end;
  finally
    FServer.Free;
    FServer := nil;
  end;
end;

procedure TGameServerApp.Stop;
begin
  FRunning := False;
end;

class procedure TGameServerApp.RunApp;
begin
  ServerApp := TGameServerApp.Create;
  try
    ServerApp.ParseArgs;
    ServerApp.Run;
  finally
    ServerApp.Free;
  end;
end;

end.
