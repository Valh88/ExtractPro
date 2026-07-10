unit LobbyManager;

{$mode objfpc}{$H+}
{$modeswitch functionreferences}
{$modeswitch anonymousfunctions}

interface

uses
  SysUtils, Classes, CastleTransform, CastleScene,
  GameWorldServer, LobbyServer, Interfaces, ServerEntityFactory,
  ServerDbSystem, AuthTypes, DbCore,
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
    FLobbyServer: TLobbyServer;
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
    function AddLobby(const APort, AMaxPlayers: Word; const ARequireAuth: Boolean = False): UInt32;
    procedure AddMatchmakingLobby(const APort: Word; const AMaxPlayers: Integer = 64; const ARequireAuth: Boolean = False);
    procedure RemoveLobby(const AId: UInt32);
    function FindLobbyById(const AId: UInt32): TGameWorldServer;
    function FindLobbyByPlayerId(const APlayerId: UInt32): TGameWorldServer;
    procedure UpdateAll(const SecondsPassed: Single);
    function GetCount: Integer;
    procedure SetDatabase(const AValue: TGameDatabase);
    property Database: TGameDatabase read FDatabase write SetDatabase;
    property AuthValidator: IAuthValidator read FValidator write FValidator;
    property OnLog: TNotifyEvent read FOnLog write FOnLog;
    property Lobbies: TLobbyArray read FLobbies;
    property LobbyServer: TLobbyServer read FLobbyServer;
    property Count: Integer read GetCount;
  end;

implementation

{ TLobbyManager }

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

function TLobbyManager.AddLobby(const APort, AMaxPlayers: Word; const ARequireAuth: Boolean): UInt32;
var
  Lobby: TLobbyInfo;
  WorldRoot: TCastleAbstractRootTransform;
  Design: TCastleTransformDesign;
  idx: Integer;
begin
  idx := FindLobbyByPort(APort);
  if idx <> -1 then
    raise Exception.CreateFmt('Lobby on port %d already exists', [APort]);

  WorldRoot := TCastleRootTransform.Create(nil);
  Design := TCastleTransformDesign.Create(nil);
  {$ifdef VISUAL}
  Design.Url := 'castle-data:/physics_scene.castle-transform';
  {$else}
  Design.Url := 'castle-data:/physics_scene_headless.castle-transform';
  {$endif}
  WorldRoot.Add(Design);
  WorldRoot.UpdateIncreaseTime(0);

  Lobby.Id := FNextId;
  Lobby.Port := APort;
  Lobby.MaxPlayers := AMaxPlayers;
  Lobby.World := TGameWorldServer.Create(WorldRoot, FFactory, APort, AMaxPlayers);
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
begin
  if FLobbyServer <> nil then
    raise Exception.Create('Matchmaking lobby already exists');
  FLobbyServer := TLobbyServer.Create(APort, AMaxPlayers);
  FLobbyServer.RequireAuth := ARequireAuth;
  if FValidator <> nil then
    FLobbyServer.AuthValidator := FValidator;
  if FLobbyDbSystem <> nil then
    FLobbyServer.SetDbSystem(FLobbyDbSystem);
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
  LS := FLobbyServer;
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
