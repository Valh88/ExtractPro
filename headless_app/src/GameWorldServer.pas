unit GameWorldServer;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

  uses
    SysUtils, StrUtils, GameWorld, WorldBridge, CastleTransform, CastleVectors, Interfaces, ServerNetSystem, RNL, NetMessages,
    ServerSnapshotSystem, ServerShotSystem, ServerDbSystem,
    JobQueueSystem, GameSettings;

type
  TGameWorldServer = class(TGameWorld)
  protected
    FWorldRoot: TCastleAbstractRootTransform;
    FPort: Word;
    FMaxPlayers: Integer;
    FNetSystem: TServerNetSystem;
    FShotSystem: TServerShotSystem;
    FDbSystem: TServerDbSystem;
    FSettings: TGameSettings;
    FFsm: TServerGameFsm;
    function GeTServerGameState: TServerGameState;
    procedure RegisterSystems; override;
    procedure CollectSpawnPoints;
  public
    procedure Update(const SecondsPassed: Single); override;
    constructor Create(const ARoot: TCastleAbstractRootTransform;
      const AFactory: IEntityFactory; const APort: Word = 7777;
      const AMaxPlayers: Integer = 8; const ASettings: PGameSettings = nil);
    destructor Destroy; override;
    procedure EnsureMapLoaded;
    procedure LoadMapData;
    procedure SetDbSystem(aDbSystem: TServerDbSystem);
    property NetSystem: TServerNetSystem read FNetSystem;
    property DbSystem: TServerDbSystem read FDbSystem;
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
  FFsm.RegisterState(sgsLoading, TLoadingState.Create(Self));
  FFsm.RegisterState(sgsWaitingPlayers, TWaitingPlayersState.Create(Self));
  FFsm.RegisterState(sgsPlaying, TPlayingState.Create(Self));
  FFsm.RegisterState(sgsFinished, TFinishedState.Create(Self));
  FFsm.ChangeState(sgsLoading);
end;

function TGameWorldServer.GeTServerGameState: TServerGameState;
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

destructor TGameWorldServer.Destroy;
begin
  FFsm.Free;
  inherited;
end;

procedure TGameWorldServer.RegisterSystems;
begin
  inherited;
  FNetSystem := TServerNetSystem.Create(Self, FPort, FMaxPlayers);
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
end;

procedure TGameWorldServer.Update(const SecondsPassed: Single);
begin
  FFsm.Update(SecondsPassed);
  inherited Update(SecondsPassed);
  {$ifndef VISUAL}
  FWorldRoot.UpdateIncreaseTime(SecondsPassed);
  {$endif}
end;

end.