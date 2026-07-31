unit LobbyManager;

{$mode objfpc}{$H+}
{$modeswitch functionreferences}
{$modeswitch anonymousfunctions}

interface

uses
  SysUtils, Classes, CastleTransform, CastleScene,
  GameWorldServer, Interfaces, ServerEntityFactory,
  ServerDbSystem, AuthTypes, DbCore, GameSettings,
  System.Threading;

type
  TLobbyInfo = record
    Id: UInt32;
    Port: Word;
    MaxPlayers: Word;
    World: TGameWorldServer;
  end;

  TLobbyArray = array of TLobbyInfo;

  TLobbyManager = class
  private
    FLobbies: TLobbyArray;
    FLobbyServer: TObject;
    FLobbyDbSystem: TServerDbSystem;
    FFactory: IEntityFactory;
    FNextId: UInt32;
    FDatabase: TGameDatabase;
    FValidator: IAuthValidator;
    FOnLog: TNotifyEvent;
    function FindLobbyByPort(APort: Word): Integer;
  public
    constructor Create(const AFactory: IEntityFactory);
    destructor Destroy; override;
    function AddLobby(const APort, AMaxPlayers: Word; const ARequireAuth: Boolean = False;
      const ASettings: PGameSettings = nil): UInt32;
    procedure AddMatchmakingLobby(const APort: Word; const AMaxPlayers: Integer = 64; const ARequireAuth: Boolean = False);
    procedure RemoveLobby(const AId: UInt32);
    function FindLobbyById(const AId: UInt32): TGameWorldServer;
    function FindLobbyByPlayerId(const APlayerId: UInt32): TGameWorldServer;
    procedure UpdateAll(const SecondsPassed: Single);
    function GetCount: Integer;
    procedure SetDatabase(const AValue: TGameDatabase);
    procedure StartLobbyServer;
    property Database: TGameDatabase read FDatabase write SetDatabase;
    property AuthValidator: IAuthValidator read FValidator write FValidator;
    property OnLog: TNotifyEvent read FOnLog write FOnLog;
    function GetGameLobbyPort: Word;
    function GetAvailablePort(const StartFrom: Word = 7777; const EndAt: Word = 7995): Word;
    property Lobbies: TLobbyArray read FLobbies;
    property Count: Integer read GetCount;
  end;

implementation

uses LobbyServer, LobbyManagerSystem;

{ TLobbyManager }

procedure TLobbyManager.StartLobbyServer;
begin
  if FLobbyServer <> nil then
    TLobbyServer(FLobbyServer).Start;
end;

constructor TLobbyManager.Create(const AFactory: IEntityFactory);
begin
  inherited Create;
  FFactory := AFactory;
  FNextId := 1;
  FDatabase := nil;
  FValidator := nil;
  FOnLog := nil;
end;

destructor TLobbyManager.Destroy;
var
  i: Integer;
begin
  FLobbyServer.Free;
  for i := 0 to High(FLobbies) do
    FLobbies[i].World.Free;
  FLobbies := nil;
  FLobbyDbSystem.Free;
  FFactory := nil;
  inherited;
end;

procedure TLobbyManager.SetDatabase(const AValue: TGameDatabase);
begin
  FDatabase := AValue;
  FLobbyDbSystem.Free;
  FLobbyDbSystem := nil;
  if FDatabase <> nil then
    FLobbyDbSystem := TServerDbSystem.CreateWithDB(FDatabase);
end;

function TLobbyManager.AddLobby(const APort, AMaxPlayers: Word; const ARequireAuth: Boolean;
  const ASettings: PGameSettings): UInt32;
var
  Lobby: TLobbyInfo;
  WorldRoot: TCastleAbstractRootTransform;
  Design: TCastleTransformDesign;
  S: TGameSettings;
  idx: Integer;
begin
  idx := FindLobbyByPort(APort);
  if idx <> -1 then
    raise Exception.CreateFmt('Lobby on port %d already exists', [APort]);

  if ASettings <> nil then
    S := ASettings^
  else
    S := DefaultGameSettings;

  WorldRoot := TCastleRootTransform.Create(nil);
  Design := TCastleTransformDesign.Create(nil);
  if S.MapUrl.Headless <> '' then
    Design.Url := S.MapUrl.Headless
  else
    Design.Url := S.MapUrl.Render;
  WorldRoot.Add(Design);

  Lobby.Id := FNextId;
  Lobby.Port := APort;
  Lobby.MaxPlayers := AMaxPlayers;
  Lobby.World := TGameWorldServer.Create(WorldRoot, FFactory, APort, AMaxPlayers, @S);
  Lobby.World.NetSystem.RequireAuth := ARequireAuth;

  if FValidator <> nil then
    Lobby.World.NetSystem.AuthValidator := FValidator;

  if FLobbyDbSystem <> nil then
    Lobby.World.SetDbSystem(FLobbyDbSystem);

  Lobby.World.Start;

  Inc(FNextId);
  SetLength(FLobbies, Length(FLobbies) + 1);
  FLobbies[High(FLobbies)] := Lobby;

  Result := Lobby.Id;

  if Assigned(FOnLog) then
    FOnLog(Self);
end;

procedure TLobbyManager.AddMatchmakingLobby(const APort: Word; const AMaxPlayers: Integer; const ARequireAuth: Boolean);
var
  LS: TLobbyServer;
  MgrSys: TLobbyManagerSystem;
begin
  if FLobbyServer <> nil then
    raise Exception.Create('Matchmaking lobby already exists');
  FLobbyServer := TLobbyServer.Create(APort, AMaxPlayers);
  LS := TLobbyServer(FLobbyServer);
  MgrSys := TLobbyManagerSystem.Create(Self);
  MgrSys.RequireAuth := ARequireAuth;
  LS.AddSystem(MgrSys);
  LS.RequireAuth := ARequireAuth;
  LS.NetSystem.ManagerSystem := MgrSys;
  MgrSys.OnSendToPlayer := @LS.NetSystem.SendToPlayer;
  if FValidator <> nil then
    LS.AuthValidator := FValidator;
  if FLobbyDbSystem <> nil then
    LS.SetDbSystem(FLobbyDbSystem);
end;

procedure TLobbyManager.RemoveLobby(const AId: UInt32);
var
  i: Integer;
begin
  for i := 0 to High(FLobbies) do
    if FLobbies[i].Id = AId then
    begin
      FLobbies[i].World.Free;
      FLobbies[i] := FLobbies[High(FLobbies)];
      SetLength(FLobbies, Length(FLobbies) - 1);
      Exit;
    end;
end;

function TLobbyManager.FindLobbyById(const AId: UInt32): TGameWorldServer;
var
  i: Integer;
begin
  for i := 0 to High(FLobbies) do
    if FLobbies[i].Id = AId then
      Exit(FLobbies[i].World);
  Result := nil;
end;

function TLobbyManager.FindLobbyByPlayerId(const APlayerId: UInt32): TGameWorldServer;
var
  i: Integer;
begin
  for i := 0 to High(FLobbies) do
    if FLobbies[i].World.NetSystem.Server.GetPeerEntityIdByPlayerId(APlayerId) <> 0 then
      Exit(FLobbies[i].World);
  Result := nil;
end;

function TLobbyManager.GetGameLobbyPort: Word;
begin
  if Length(FLobbies) = 0 then
    raise Exception.Create('No game lobbies available');
  Result := FLobbies[0].Port;
end;

function TLobbyManager.GetAvailablePort(const StartFrom: Word; const EndAt: Word): Word;
var
  P: Word;
begin
  for P := StartFrom to EndAt do
    if FindLobbyByPort(P) = -1 then
      Exit(P);
  raise Exception.CreateFmt('No available ports in range %d..%d', [StartFrom, EndAt]);
end;

function TLobbyManager.GetCount: Integer;
begin
  Result := Length(FLobbies);
end;

function TLobbyManager.FindLobbyByPort(APort: Word): Integer;
var
  i: Integer;
begin
  for i := 0 to High(FLobbies) do
    if FLobbies[i].Port = APort then
      Exit(i);
  Result := -1;
end;

procedure TLobbyManager.UpdateAll(const SecondsPassed: Single);
var
  L: TLobbyArray;
  LS: TLobbyServer;
  SP: Single;
begin
  L := FLobbies;
  LS := TLobbyServer(FLobbyServer);
  SP := SecondsPassed;
  TParallel.&For(-1, High(L), procedure(i: Integer)
  begin
    if i = -1 then
      LS.Update(SP)
    else
      L[i].World.Update(SP);
  end);
end;

end.
