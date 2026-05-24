unit GameServerApp;

{$mode objfpc}{$H+}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes,
  CastleTransform, CastleScene,
  help_types, Interfaces, WorldTypes, GameWorld, GameConfig,
  ServerEntityFactory, GameWorldServer, AuthTypes;

type
  TGameServerApp = class;
  TGameServerAppProc = reference to procedure(const App: TGameServerApp);
  TTickEvent = reference to procedure(Sender: TObject; const SecondsPassed: Single);
  TLogEvent = reference to procedure(Sender: TObject; const Msg: String);

  TGameServerApp = class
  private
    FWorldRoot: TCastleAbstractRootTransform;
    FGameWorld: TGameWorldServer;
    FPort: Word;
    FMaxPlayers: Integer;
    FAuthPort: Word;
    FRequireAuth: Boolean;
    FRunning: Boolean;
    FTickCount: Int64;
    FOnTick: TTickEvent;
    FOnLog: TLogEvent;
    procedure Log(const Msg: String);
    procedure LoadScene;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ParseArgs;
    procedure Run;
    procedure Stop;
    class procedure RunApp(const ASetup: TGameServerAppProc = nil);
    property GameWorld: TGameWorldServer read FGameWorld;
    property Port: Word read FPort write FPort;
    property MaxPlayers: Integer read FMaxPlayers write FMaxPlayers;
    property AuthPort: Word read FAuthPort write FAuthPort;
    property RequireAuth: Boolean read FRequireAuth write FRequireAuth;
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
  FAuthPort := AUTH_SERVER_DEFAULT_PORT;
  FRequireAuth := False;
  FRunning := False;
  FTickCount := 0;
end;

destructor TGameServerApp.Destroy;
begin
  Stop;
  FGameWorld.Free;
  FWorldRoot.Free;
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
      FMaxPlayers := StrToIntDef(S.SubString(14), 8)
    else if S.StartsWith('--auth-port=') then
      FAuthPort := StrToIntDef(S.SubString(12), AUTH_SERVER_DEFAULT_PORT)
    else if S = '--no-auth' then
      FAuthPort := 0
    else if S = '--require-auth' then
      FRequireAuth := True;
  end;
end;

procedure TGameServerApp.LoadScene;
var
  Design: TCastleTransformDesign;
  Factory: IEntityFactory;
begin
  FWorldRoot := TCastleRootTransform.Create(nil);
  Design := TCastleTransformDesign.Create(nil);
  {$ifdef VISUAL}
  Design.Url := 'castle-data:/physics_scene.castle-transform';
  {$else}
  Design.Url := 'castle-data:/physics_scene_headless.castle-transform';
  {$endif}
  FWorldRoot.Add(Design);
  FWorldRoot.UpdateIncreaseTime(0);

  {$ifdef VISUAL}
  Factory := TServerEntityFactory.Create('castle-data:/PlayerProtoNoCamera.castle-transform', '');
  {$else}
  Factory := TServerEntityFactory.Create('castle-data:/PlayerProtoNoCamera.castle-transform', '');
  {$endif}
  FGameWorld := TGameWorldServer.Create(FWorldRoot, Factory, FPort, FMaxPlayers, FAuthPort, FRequireAuth);
  FGameWorld.Start;
end;

procedure TGameServerApp.Run;
const
  DT = 1 / 60;
begin
  if FRunning then Exit;
  FRunning := True;

  LoadScene;

  if FGameWorld.NetSystem <> nil then
    FGameWorld.NetSystem.StartServer;

  if FAuthPort > 0 then
    Log(Format('Auth Server on port %d', [FAuthPort]));

  if FRequireAuth then
    Log('Auth required for all connections');

  Log(Format('ExtractPro Server starting on port %d (max %d players)',
    [FPort, FMaxPlayers]));
  Log('Server running. Press Ctrl+C to stop.');

  try
    while FRunning do
    begin
      FGameWorld.Update(DT);
      {$ifndef VISUAL}
      FWorldRoot.UpdateIncreaseTime(DT);
      {$endif}
      if Assigned(FOnTick) then
        FOnTick(Self, DT);

      Inc(FTickCount);
      if (FTickCount mod 3600) = 0 then
        Log(Format('[%d] Players: %d', [FTickCount div 60,
          FGameWorld.NetSystem.Server.Peers]));

      Sleep(Round(DT * 1000));
    end;
  finally
  end;
end;

procedure TGameServerApp.Stop;
begin
  FRunning := False;
end;

class procedure TGameServerApp.RunApp(const ASetup: TGameServerAppProc);
begin
  ServerApp := TGameServerApp.Create;
  try
    if Assigned(ASetup) then
      ASetup(ServerApp);
    ServerApp.ParseArgs;
    ServerApp.Run;
  finally
    ServerApp.Free;
  end;
end;

end.