unit GameWorldServer;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

  uses
    SysUtils, StrUtils, GameWorld, WorldBridge, CastleTransform, CastleVectors, Interfaces, ServerNetSystem, RNL, NetMessages,
    ServerSnapshotSystem, ServerShotSystem, ServerDbSystem,
    JobQueueSystem, GameSettings, CastleLog,
    help_types, EntityTypes, ExtractPointSystem, ServerPartySystem;
type
  TMatchPlayerInfo = record
    PlayerId: UInt32;  // id игрока в лобби (matchmaking)
    PartySize: Byte;   // 1 = соло, 3 = трио
  end;

  TEntityMatchLink = record
    EntityId: TEntityId;
    MatchIndex: Integer; // индекс в FMatchPlayers, -1 = не связан
  end;

  TGameWorldServer = class(TGameWorld)
  private
    FWorldRoot: TCastleAbstractRootTransform;
    FPort: Word;
    FMaxPlayers: Integer;
    FNetSystem: TServerNetSystem;
    FShotSystem: TServerShotSystem;
    FDbSystem: TServerDbSystem;
    FPartySystem: TServerPartySystem;
    FSettings: TGameSettings;
    FFsm: TServerGameFsm;
    FMatchPlayers: array of TMatchPlayerInfo;
    FMatchTeams: array of Byte;          // команда на индекс матча, 255 = не назначена
    FEntityToMatch: array of TEntityMatchLink;
  protected
    procedure OnStateChanged(NewState, OldState: TServerGameState);
    function GeTServerGameState: TServerGameState;
    function GetGameState: TServerGameState; override;
    procedure RegisterSystems; override;
    procedure CollectSpawnPoints;
  public
    procedure Update(const SecondsPassed: Single); override;
    constructor Create(const ARoot: TCastleAbstractRootTransform;
      const AFactory: IEntityFactory; const APort: Word = 7777;
      const AMaxPlayers: Integer = 8; const ASettings: PGameSettings = nil);
    destructor Destroy; override;
    procedure StartServer;
    procedure EnsureMapLoaded;
    procedure LoadMapData;
    procedure SetDbSystem(aDbSystem: TServerDbSystem);
    procedure SetMatchPlayers(const APlayers: array of TMatchPlayerInfo);
    procedure RegisterPlayer(const AEntityId: TEntityId; const ALobbyPlayerId: UInt32);
    function IsMatchFull: Boolean;
    function GetTeamForEntity(const AEntityId: TEntityId): Integer;
    function GetPartyInfo(const AEntityId: TEntityId; out Info: TPartyInfoData): Boolean;
    procedure DistributeParties;
    property NetSystem: TServerNetSystem read FNetSystem;
    property DbSystem: TServerDbSystem read FDbSystem;
    property PartySystem: TServerPartySystem read FPartySystem;
    property Settings: TGameSettings read FSettings write FSettings;
    property GameState: TServerGameState read GeTServerGameState;
  end;

implementation

uses GameStates;

{ TGameWorldServer }

constructor TGameWorldServer.Create(const ARoot: TCastleAbstractRootTransform;
  const AFactory: IEntityFactory; const APort: Word;
  const AMaxPlayers: Integer; const ASettings: PGameSettings);
var
  B: TWorldBridge;
begin
  FWorldRoot := ARoot;
  FPort := APort;
  FMaxPlayers := AMaxPlayers;
  if ASettings <> nil then
    FSettings := ASettings^
  else
    FSettings := DefaultGameSettings;
  B := TWorldBridge.Create(ARoot);
  inherited Create(B as IGameWorld, AFactory);
  B.GameLogic := Self;

  FFsm := TServerGameFsm.Create;
  FFsm.RegisterState(sgsStart, TStartState.Create(Self));
  FFsm.RegisterState(sgsLoading, TLoadingState.Create(Self));
  FFsm.RegisterState(sgsWaitingPlayers, TWaitingPlayersState.Create(Self));
  FFsm.RegisterState(sgsCountdown, TCountdownState.Create(Self));
  FFsm.RegisterState(sgsPlaying, TPlayingState.Create(Self));
  FFsm.RegisterState(sgsFinished, TFinishedState.Create(Self));
  FFsm.AddStateChangeListener(@OnStateChanged);
  FFsm.ChangeState(sgsStart);
end;

function TGameWorldServer.GeTServerGameState: TServerGameState;
begin
  Result := FFsm.CurrentState;
end;

function TGameWorldServer.GetGameState: TServerGameState;
begin
  Result := FFsm.CurrentState;
end;

procedure TGameWorldServer.SetDbSystem(aDbSystem: TServerDbSystem);
begin
  FDbSystem := aDbSystem;
  if aDbSystem <> nil then
    AddSystem(aDbSystem);
end;

procedure TGameWorldServer.EnsureMapLoaded;
begin
  FWorldRoot.UpdateIncreaseTime(0);
end;

procedure TGameWorldServer.LoadMapData;
begin
  CollectSpawnPoints;
end;

procedure TGameWorldServer.CollectSpawnPoints;
var
  LocalSpawn: array of TSpawnPoint;
  LocalTeams: array of TTeamSpawnSet;

  procedure AddSpawnPoint(const AGroup: string; const ASpawn: TSpawnPoint);
  var
    i, L, TeamIdx: Integer;
  begin
    if AGroup = '' then
    begin
      L := Length(LocalSpawn);
      SetLength(LocalSpawn, L + 1);
      LocalSpawn[L] := ASpawn;
    end else
    begin
      TeamIdx := -1;
      for i := 0 to High(LocalTeams) do
        if LocalTeams[i].Name = AGroup then
          TeamIdx := i;
      if TeamIdx = -1 then
      begin
        L := Length(LocalTeams);
        SetLength(LocalTeams, L + 1);
        TeamIdx := L;
        LocalTeams[TeamIdx].Name := AGroup;
      end;
      L := Length(LocalTeams[TeamIdx].Points);
      SetLength(LocalTeams[TeamIdx].Points, L + 1);
      LocalTeams[TeamIdx].Points[L] := ASpawn;
    end;
  end;

  procedure Walk(const ATransform: TCastleTransform);
  var
    i, Und: Integer;
    Rest, NumPart, Group: string;
    N: Integer;
    Sp: TSpawnPoint;
    R: TVector4;
  begin
    if ATransform = nil then
      Exit;
    if Copy(ATransform.Name, 1, 6) = 'Spawn_' then
    begin
      Rest := Copy(ATransform.Name, 7, MaxInt);
      Und := RPos('_', Rest);
      if Und > 0 then
      begin
        Group := Copy(Rest, 1, Und - 1);
        NumPart := Copy(Rest, Und + 1, MaxInt);
      end else
      begin
        Group := '';
        NumPart := Rest;
      end;
      if TryStrToInt(NumPart, N) then
      begin
        Sp.Pos := ATransform.Translation;
        R := ATransform.Rotation;
        if (Abs(R.X) < 0.001) and (Abs(R.Z) < 0.001) and (Abs(R.Y) > 0.5) then
        begin
          if R.Y > 0 then
            Sp.RotY := R.W
          else
            Sp.RotY := -R.W;
        end else
          Sp.RotY := 0;
        AddSpawnPoint(Group, Sp);
      end;
    end;
    for i := 0 to ATransform.Count - 1 do
      Walk(ATransform.Items[i]);
  end;

begin
  Walk(FWorldRoot);
  if Length(LocalSpawn) > 0 then
    FSettings.SpawnPoints := LocalSpawn;
  if Length(LocalTeams) > 0 then
    FSettings.TeamSpawnSets := LocalTeams;
end;

procedure TGameWorldServer.SetMatchPlayers(const APlayers: array of TMatchPlayerInfo);
var
  i: Integer;
begin
  FMatchPlayers := nil;
  FMatchTeams := nil;
  FEntityToMatch := nil;
  if FPartySystem <> nil then
    FPartySystem.ResetParties;
  SetLength(FMatchPlayers, Length(APlayers));
  SetLength(FMatchTeams, Length(APlayers));
  for i := 0 to High(APlayers) do
  begin
    FMatchPlayers[i] := APlayers[i];
    FMatchTeams[i] := 255;
  end;
  if Length(APlayers) > 0 then
    WritelnLog('Server', 'Match players set: %d (party size %d)',
      [Length(APlayers), APlayers[0].PartySize]);
end;

procedure TGameWorldServer.RegisterPlayer(const AEntityId: TEntityId; const ALobbyPlayerId: UInt32);
var
  i, TeamCount, PartySize: Integer;
  L: TEntityMatchLink;
begin
  for i := 0 to High(FEntityToMatch) do
    if FEntityToMatch[i].EntityId = AEntityId then
      Exit;
  L.MatchIndex := -1;
  for i := 0 to High(FMatchPlayers) do
    if FMatchPlayers[i].PlayerId = ALobbyPlayerId then
    begin
      L.MatchIndex := i;
      Break;
    end;
  if L.MatchIndex >= 0 then
  begin
    TeamCount := Length(FSettings.TeamSpawnSets);
    PartySize := FMatchPlayers[0].PartySize;
    if (TeamCount > 0) and (PartySize > 0) then
      FMatchTeams[L.MatchIndex] := Byte((L.MatchIndex div PartySize) mod TeamCount);
  end;
  L.EntityId := AEntityId;
  SetLength(FEntityToMatch, Length(FEntityToMatch) + 1);
  FEntityToMatch[High(FEntityToMatch)] := L;
  WritelnLog('Server', 'Player registered: entity=%d lobbyPlayerId=%d matchIndex=%d',
    [AEntityId, ALobbyPlayerId, L.MatchIndex]);
end;

function TGameWorldServer.IsMatchFull: Boolean;
var
  i, j: Integer;
  Linked: Boolean;
begin
  if Length(FMatchPlayers) = 0 then
    Exit(True);
  for i := 0 to High(FMatchPlayers) do
  begin
    Linked := False;
    for j := 0 to High(FEntityToMatch) do
      if FEntityToMatch[j].MatchIndex = i then
      begin
        Linked := True;
        Break;
      end;
    if not Linked then
      Exit(False);
  end;
  Result := True;
end;

function TGameWorldServer.GetTeamForEntity(const AEntityId: TEntityId): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(FEntityToMatch) do
    if (FEntityToMatch[i].EntityId = AEntityId) and (FEntityToMatch[i].MatchIndex >= 0) then
    begin
      Result := FMatchTeams[FEntityToMatch[i].MatchIndex];
      if Result = 255 then
        Result := -1;
      Exit;
    end;
end;

function TGameWorldServer.GetPartyInfo(const AEntityId: TEntityId; out Info: TPartyInfoData): Boolean;
var
  i, Mi, PartySize, PartyIdx: Integer;
begin
  Result := False;
  for i := 0 to High(FEntityToMatch) do
    if FEntityToMatch[i].EntityId = AEntityId then
    begin
      Mi := FEntityToMatch[i].MatchIndex;
      if (Mi < 0) or (Mi >= Length(FMatchTeams)) or (FMatchTeams[Mi] = 255) then
        Exit;
      Info.TeamIndex := FMatchTeams[Mi];
      Info.MemberIds := nil;
      PartySize := FMatchPlayers[Mi].PartySize;
      if PartySize > 0 then
      begin
        PartyIdx := Mi div PartySize;
        if (FPartySystem <> nil) and (PartyIdx < FPartySystem.PartyCount) then
          for Mi := 0 to FPartySystem.GetPartyMemberCount(PartyIdx) - 1 do
          begin
            SetLength(Info.MemberIds, Length(Info.MemberIds) + 1);
            Info.MemberIds[High(Info.MemberIds)] := FPartySystem.GetPartyMember(PartyIdx, Mi);
          end;
      end;
      Info.MemberCount := Byte(Length(Info.MemberIds));
      Result := True;
      Exit;
    end;
end;

procedure TGameWorldServer.DistributeParties;
var
  i, Mi, PartySize, TeamCount, PartyIdx, SpIdx: Integer;
  TeamUsed: array of Integer;
  Sp: TSpawnPoint;
  Spawned: Boolean;
  E: IGameEntity;
  Info: TPartyInfoData;
  M: TNetMessage;
  Pid: UInt32;
  LocalParties: array of TPartyData;
begin
  if Length(FMatchPlayers) = 0 then
    Exit;
  TeamCount := Length(FSettings.TeamSpawnSets);
  if TeamCount = 0 then
    TeamCount := 1;
  PartySize := FMatchPlayers[0].PartySize;
  if PartySize = 0 then
    PartySize := 1;

  LocalParties := nil;
  for i := 0 to High(FMatchPlayers) do
  begin
    FMatchTeams[i] := Byte((i div PartySize) mod TeamCount);
    PartyIdx := i div PartySize;
    if Length(LocalParties) <= PartyIdx then
      SetLength(LocalParties, PartyIdx + 1);
    if Length(LocalParties[PartyIdx].Members) = 0 then
      LocalParties[PartyIdx].TeamIndex := FMatchTeams[i];
    SetLength(LocalParties[PartyIdx].Members, Length(LocalParties[PartyIdx].Members) + 1);
    LocalParties[PartyIdx].Members[High(LocalParties[PartyIdx].Members)] := 0;
  end;
  for i := 0 to High(FEntityToMatch) do
  begin
    Mi := FEntityToMatch[i].MatchIndex;
    if (Mi < 0) or (Mi >= Length(FMatchPlayers)) then Continue;
    PartyIdx := Mi div PartySize;
    if (PartyIdx < Length(LocalParties)) then
      LocalParties[PartyIdx].Members[(Mi mod PartySize)] := FEntityToMatch[i].EntityId;
  end;
  if FPartySystem <> nil then
    FPartySystem.SetParties(LocalParties);
  WritelnLog('Server', 'Parties distributed: %d parties, %d teams',
    [Length(LocalParties), TeamCount]);

  SetLength(TeamUsed, TeamCount);
  for i := 0 to High(FEntityToMatch) do
  begin
    Mi := FEntityToMatch[i].MatchIndex;
    if Mi < 0 then
      Continue;
    E := FindEntity(FEntityToMatch[i].EntityId);
    if E = nil then
      Continue;
    SpIdx := TeamUsed[FMatchTeams[Mi]];
    Spawned := False;
    if (FMatchTeams[Mi] < TeamCount) and
       (Length(FSettings.TeamSpawnSets[FMatchTeams[Mi]].Points) > 0) then
    begin
      Sp := FSettings.TeamSpawnSets[FMatchTeams[Mi]].Points[
        SpIdx mod Length(FSettings.TeamSpawnSets[FMatchTeams[Mi]].Points)];
      Spawned := True;
    end;
    if not Spawned and (SpIdx < Length(FSettings.SpawnPoints)) then
      Sp := FSettings.SpawnPoints[SpIdx]
    else if not Spawned then
      Sp.Pos := Vector3(0, 5, 0);
    Inc(TeamUsed[FMatchTeams[Mi]]);
    E.Transform.Translation := Sp.Pos;
    E.Transform.Rotation := Vector4(0, 1, 0, Sp.RotY);
    WritelnLog('Server', 'Entity %d teleported to team %d spawn (%s)',
      [FEntityToMatch[i].EntityId, FMatchTeams[Mi], Sp.Pos.ToString]);
  end;

  for i := 0 to High(FEntityToMatch) do
  begin
    if FEntityToMatch[i].MatchIndex < 0 then
      Continue;
    Pid := FNetSystem.Server.FindPlayerIdByEntityId(FEntityToMatch[i].EntityId);
    if Pid = 0 then
      Continue;
    if GetPartyInfo(FEntityToMatch[i].EntityId, Info) then
    begin
      M.Init(msgPartyInfo, Info.ToBytes);
      FNetSystem.SendToPlayer(Pid, M);
      WritelnLog('Server', 'PartyInfo sent to player %d: team=%d members=%d',
        [Pid, Info.TeamIndex, Info.MemberCount]);
    end;
  end;
end;

destructor TGameWorldServer.Destroy;
begin
  FFsm.Free;
  inherited;
end;

procedure TGameWorldServer.RegisterSystems;
var
  ExtractSys: TExtractPointSystem;
begin
  inherited;
  FNetSystem := TServerNetSystem.Create(Self, FPort, FMaxPlayers);
  FNetSystem.Settings := @FSettings;
  FNetSystem.OnPlayerRegistered := @RegisterPlayer;
  FNetSystem.OnGetPlayerTeam := @GetTeamForEntity;
  FShotSystem := TServerShotSystem.Create(Self);
  FNetSystem.ShotSystem := FShotSystem;
  FShotSystem.SendHitProc := procedure(const APlayerId: UInt32; const HitData: THitData)
  var
    M: TNetMessage;
  begin
    M.Init(msgHit, HitData.ToBytes);
    FNetSystem.Broadcast(M);
  end;
  AddSystem(FNetSystem);
  AddSystem(TServerSnapshotSystem.Create(Self, FNetSystem.Server));
  AddSystem(FShotSystem);
  AddSystem(TJobQueueSystem.Create(Self));
  ExtractSys := TExtractPointSystem.Create(Self, FWorldRoot);
  ExtractSys.SendZoneEventProc := procedure(const ZoneEvent: TExtractZoneEvent)
  var
    M: TNetMessage;
  begin
    M.Init(msgExtractZone, ZoneEvent.ToBytes);
    FNetSystem.Broadcast(M);
  end;
  AddSystem(ExtractSys);
  FPartySystem := TServerPartySystem.Create(Self);
  AddSystem(FPartySystem);
end;

procedure TGameWorldServer.Update(const SecondsPassed: Single);
begin
  FFsm.Update(SecondsPassed);
  inherited Update(SecondsPassed);
  {$ifndef VISUAL}
  FWorldRoot.UpdateIncreaseTime(SecondsPassed);
  {$endif}
end;

procedure TGameWorldServer.StartServer;
begin
  FNetSystem.StartServer;
end;

procedure TGameWorldServer.OnStateChanged(NewState, OldState: TServerGameState);
var
  M: TNetMessage;
begin
  M.Init(msgGameStateChanged, [Byte(Ord(NewState))]);
  FNetSystem.Broadcast(M);
  WritelnLog('Server', 'Game state changed: %d -> %d', [Ord(OldState), Ord(NewState)]);
end;

end.
