unit GameServerApp;

{$mode objfpc}{$H+}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes,
  CastleTransform, CastleScene,
  help_types, Interfaces, WorldTypes, GameWorld, GameConfig,
  ServerEntityFactory, GameWorldServer, ServerDbSystem,
  LobbyManager, AuthServer, DbCore, DbAccounts,
  AuthTypes;

type
  TGameServerApp = class;
  TGameServerAppProc = reference to procedure(const App: TGameServerApp);
  TTickEvent = reference to procedure(Sender: TObject; const SecondsPassed: Single);
  TLogEvent = reference to procedure(Sender: TObject; const Msg: String);

  TGameServerApp = class
  private
    FLobbyManager: TLobbyManager;
    FFactory: IEntityFactory;
    FDatabase: TGameDatabase;
    FAuthServer: TAuthServer;
    FPort: Word;
    FLobbyPort: Word;
    FMaxPlayers: Integer;
    FAuthPort: Word;
    FRequireAuth: Boolean;
    FDBFileName: TFileName;
    FRunning: Boolean;
    FTickCount: Int64;
    FOnTick: TTickEvent;
    FOnLog: TLogEvent;
    procedure Log(const Msg: String);
    procedure SetupShared;
    procedure OnAuthRegister(Sender: TObject; const AUserId: Int64; const ALogin: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure ParseArgs;
    procedure Run;
    procedure Stop;
    class procedure RunApp(const ASetup: TGameServerAppProc = nil);
    property LobbyManager: TLobbyManager read FLobbyManager;
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
  FLobbyPort := 7776;
  FMaxPlayers := 8;
  FAuthPort := AUTH_SERVER_DEFAULT_PORT;
  FRequireAuth := False;
  FDBFileName := 'server.db';
  FRunning := False;
  FTickCount := 0;
  FLobbyManager := nil;
  FFactory := nil;
  FDatabase := nil;
  FAuthServer := nil;
end;

destructor TGameServerApp.Destroy;
begin
  Stop;
  FLobbyManager.Free;
  FAuthServer.Free;
  FDatabase.Free;
  FFactory := nil;
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
    else if S.StartsWith('--lobby-port=') then
      FLobbyPort := Word(StrToIntDef(S.SubString(13), 7776))
    else if S.StartsWith('--max-players=') then
      FMaxPlayers := StrToIntDef(S.SubString(14), 8)
    else if S.StartsWith('--auth-port=') then
      FAuthPort := StrToIntDef(S.SubString(12), AUTH_SERVER_DEFAULT_PORT)
    else if S = '--no-auth' then
      FAuthPort := 0
    else if S = '--require-auth' then
      FRequireAuth := True
    else if S.StartsWith('--db=') then
      FDBFileName := S.SubString(5);
  end;
end;

procedure TGameServerApp.OnAuthRegister(Sender: TObject; const AUserId: Int64; const ALogin: string);
var
  Acc: TOrmGameAccount;
begin
  if FDatabase = nil then Exit;
  Acc := TOrmGameAccount.Create;
  try
    Acc.AuthUserId := AUserId;
    Acc.Login := ALogin;
    FDatabase.Orm.Add(Acc, True);
  finally
    Acc.Free;
  end;
end;

procedure TGameServerApp.SetupShared;
begin
  FFactory := TServerEntityFactory.Create(
    'castle-data:/PlayerProtoNoCamera.castle-transform', '');

  if FDBFileName <> '' then
  begin
    FDatabase := TGameDatabase.Create(FDBFileName);
    Log(Format('Database: %s', [FDBFileName]));
  end;

  if FAuthPort > 0 then
  begin
    FAuthServer := TAuthServer.Create(FAuthPort);
    FAuthServer.OnRegister := @OnAuthRegister;
    FAuthServer.Start;
    Log(Format('Auth Server on port %d', [FAuthPort]));
  end;

  FLobbyManager := TLobbyManager.Create(FFactory);
  FLobbyManager.Database := FDatabase;
  if FAuthServer <> nil then
    FLobbyManager.AuthValidator := FAuthServer.Validator;

  if FRequireAuth then
    Log('Auth required for all connections');

  // FLobbyManager.AddLobby(FPort, FMaxPlayers, FRequireAuth);
  FLobbyManager.AddMatchmakingLobby(FLobbyPort, 64, FRequireAuth);
  FLobbyManager.StartLobbyServer;
  Log(Format('Lobby Server on port %d', [FLobbyPort]));
end;

procedure TGameServerApp.Run;
const
  DT = 1 / 60;
var
  i: Integer;
  TotalPlayers: Integer;
begin
  if FRunning then Exit;
  FRunning := True;

  SetupShared;

  for i := 0 to FLobbyManager.Count - 1 do
    FLobbyManager.Lobbies[i].World.NetSystem.StartServer;

  Log(Format('ExtractPro Server starting on port %d (max %d players)',
    [FPort, FMaxPlayers]));
  Log('Server running. Press Ctrl+C to stop.');

  try
    while FRunning do
    begin
      FLobbyManager.UpdateAll(DT);
      if Assigned(FOnTick) then
        FOnTick(Self, DT);

      Inc(FTickCount);
      if (FTickCount mod 3600) = 0 then
      begin
        TotalPlayers := 0;
        for i := 0 to FLobbyManager.Count - 1 do
          TotalPlayers := TotalPlayers + FLobbyManager.Lobbies[i].World.NetSystem.Server.Peers;
        Log(Format('[%d] Players: %d', [FTickCount div 60, TotalPlayers]));
      end;

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
