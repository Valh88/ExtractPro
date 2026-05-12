unit GameWorld;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, help_types, EntityTypes, WorldTypes, GameConfig, Interfaces, EventBus;

type
  TRaidPhase = (rpExploring, rpExtracting);

  TSpawnWave = record
    EnemyCount: Integer;
    Interval: Single;
    Timer: Single;
    RoomIndex: Integer;
  end;

  TGameWorld = class
  private
    FData: TGameWorldData;
    FPhase: TRaidPhase;
    FNextEntityId: TEntityId;
    FRaidTime: Single;
    FMaxRaidTime: Single;
    FExtractTime: Single;
    FSpawnWaves: array of TSpawnWave;
    FWorld: IGameWorld;
    FFactory: IEntityFactory;

    function AllocateEntityId: TEntityId;
    function FindPlayerIndex(const AEntityId: TEntityId): Integer;
    function FindEnemyIndex(const AEntityId: TEntityId): Integer;
    procedure UpdateAI(const SecondsPassed: Single);
    procedure UpdateCombat(const SecondsPassed: Single);
    procedure UpdatePvP(const SecondsPassed: Single);
    procedure UpdateExtraction(const SecondsPassed: Single);
    procedure UpdateSpawner(const SecondsPassed: Single);
    function FindClosestPlayer(const FromPos: TVector2; out Dist: Single): Integer;
    function FindAlivePlayer(const FromPos: TVector2; ExcludeId: TEntityId; out Dist: Single): Integer;
  public
    constructor Create(AWorld: IGameWorld; AFactory: IEntityFactory);
    destructor Destroy; override;

    procedure Start;
    procedure Stop;
    procedure Update(const SecondsPassed: Single);

    { Управление миром }
    function AddPlayer: Integer;
    procedure SpawnEnemy(const RoomIndex: Integer);
    procedure SpawnWave(const RoomIndex, Count: Integer; const Interval: Single);
    procedure GenerateDungeon;
    procedure StartExtraction;
    function GetData: TGameWorldData;
    procedure SetEntityVisual(const AEntityId: TEntityId; const Visual: IGameEntity);
    procedure RemoveEntity(const AEntityId: TEntityId);
    property Data: TGameWorldData read FData;
    property Phase: TRaidPhase read FPhase;
    property RaidTime: Single read FRaidTime;
    property World: IGameWorld read FWorld write FWorld;
    property Factory: IEntityFactory read FFactory write FFactory;
  end;

implementation

{ TGameWorld }

constructor TGameWorld.Create(AWorld: IGameWorld; AFactory: IEntityFactory);
begin
  inherited Create;
  FWorld := AWorld;
  FFactory := AFactory;
  FData.Init;
  FNextEntityId := 1;
  FPhase := rpExploring;
  FMaxRaidTime := GlobalConfig.RaidTime;
  FExtractTime := GlobalConfig.ExtractionTime;
end;

destructor TGameWorld.Destroy;
begin
  FData.Free;
  FWorld := nil;
  FFactory := nil;
  inherited;
end;

function TGameWorld.AllocateEntityId: TEntityId;
begin
  Result := FNextEntityId;
  Inc(FNextEntityId);
end;

function TGameWorld.FindPlayerIndex(const AEntityId: TEntityId): Integer;
begin
  for Result := 0 to High(FData.Players) do
    if FData.Players[Result].Id = AEntityId then
      Exit;
  Result := -1;
end;

function TGameWorld.FindEnemyIndex(const AEntityId: TEntityId): Integer;
begin
  for Result := 0 to High(FData.Enemies) do
    if FData.Enemies[Result].Id = AEntityId then
      Exit;
  Result := -1;
end;

procedure TGameWorld.SetEntityVisual(const AEntityId: TEntityId; const Visual: IGameEntity);
var
  Idx: Integer;
  P: TPlayerData;
begin
  Idx := FindPlayerIndex(AEntityId);
  if Idx <> -1 then
  begin
    FData.Players[Idx].Visual := Visual;
    Exit;
  end;
  Idx := FindEnemyIndex(AEntityId);
  if Idx <> -1 then
  begin
    FData.Enemies[Idx].Visual := Visual;
    Exit;
  end;
  P.Id := AEntityId;
  P.Stats.MaxHealth := 100;
  P.Stats.Health := 100;
  P.Stats.Speed := 10;
  P.Stats.Armor := 0;
  P.Init;
  P.Status := psInRaid;
  P.ExtractionProgress := 0;
  P.Kills := 0;
  P.Damage := 10;
  P.AttackRange := 5;
  P.Visual := Visual;
  SetLength(FData.Players, Length(FData.Players) + 1);
  FData.Players[High(FData.Players)] := P;
end;

procedure TGameWorld.RemoveEntity(const AEntityId: TEntityId);
var
  Idx: Integer;
  Last: Integer;
begin
  Idx := FindPlayerIndex(AEntityId);
  if Idx <> -1 then
  begin
    FData.Players[Idx].Visual := nil;
    FData.Players[Idx].Free;
    Last := High(FData.Players);
    if Idx < Last then
      FData.Players[Idx] := FData.Players[Last];
    SetLength(FData.Players, Last);
    Exit;
  end;
  Idx := FindEnemyIndex(AEntityId);
  if Idx <> -1 then
  begin
    FData.Enemies[Idx].Visual := nil;
    Last := High(FData.Enemies);
    if Idx < Last then
      FData.Enemies[Idx] := FData.Enemies[Last];
    SetLength(FData.Enemies, Last);
  end;
end;

{ IGameWorld }

procedure TGameWorld.Start;
begin
  FPhase := rpExploring;
  FRaidTime := 0;
  FData.Init;
end;

procedure TGameWorld.Stop;
begin
  FData.Free;
end;

procedure TGameWorld.Update(const SecondsPassed: Single);
var
  i: Integer;
begin
  FRaidTime := FRaidTime + SecondsPassed;
  if FRaidTime >= FMaxRaidTime then
  begin
    for i := 0 to High(FData.Players) do
      if FData.Players[i].Status = psInRaid then
      begin
        FData.Players[i].Inventory.Free;
        FData.Players[i].Status := psDead;
      end;
    Exit;
  end;

  UpdateSpawner(SecondsPassed);
  UpdateAI(SecondsPassed);
  UpdateCombat(SecondsPassed);
  UpdatePvP(SecondsPassed);

  if FPhase = rpExtracting then
    UpdateExtraction(SecondsPassed);

  GameEventBus.Flush;
end;

function TGameWorld.AddPlayer: Integer;
var
  P: TPlayerData;
begin
  P.Id := AllocateEntityId;
  P.Stats.MaxHealth := GlobalConfig.PlayerBaseHealth;
  P.Stats.Health := GlobalConfig.PlayerBaseHealth;
  P.Stats.Speed := GlobalConfig.PlayerBaseSpeed;
  P.Stats.Armor := 0;
  P.Init;
  P.Status := psInRaid;
  P.ExtractionProgress := 0;
  P.Kills := 0;
  P.Damage := GlobalConfig.PlayerBaseDamage;
  P.AttackRange := GlobalConfig.PlayerAttackRange;

  SetLength(FData.Players, Length(FData.Players) + 1);
  FData.Players[High(FData.Players)] := P;
  Result := High(FData.Players);

  if (FWorld <> nil) and (FFactory <> nil) then
    FWorld.RegisterEntity(FFactory.CreatePlayerEntity(P.Id));
end;

procedure TGameWorld.StartExtraction;
var
  i: Integer;
begin
  FPhase := rpExtracting;
  for i := 0 to High(FData.Players) do
    FData.Players[i].IsExtracting := True;
end;

procedure TGameWorld.SpawnEnemy(const RoomIndex: Integer);
var
  E: TEnemyData;
  Ev: TGameEvent;
begin
  if (RoomIndex < 0) or (RoomIndex >= Length(FData.Rooms)) then
    Exit;

  E.Id := AllocateEntityId;
  E.Stats.MaxHealth := GlobalConfig.EnemyBaseHealth + Random(20);
  E.Stats.Health := E.Stats.MaxHealth;
  E.Stats.Speed := GlobalConfig.EnemyBaseSpeed;
  E.Stats.Armor := 0;
  E.AIState := asIdle;
  E.DetectionRange := GlobalConfig.EnemyDetectionRange;
  E.AttackRange := GlobalConfig.EnemyAttackRange;
  E.Damage := GlobalConfig.EnemyBaseDamage;
  E.LootTable := nil;
  E.SpawnPosition.X := FData.Rooms[RoomIndex].Bounds.Left + Random * FData.Rooms[RoomIndex].Bounds.Width;
  E.SpawnPosition.Y := FData.Rooms[RoomIndex].Bounds.Bottom + Random * FData.Rooms[RoomIndex].Bounds.Height;

  SetLength(FData.Enemies, Length(FData.Enemies) + 1);
  FData.Enemies[High(FData.Enemies)] := E;
  Ev.EventType := geEnemySpawned;
  Ev.EntityId := E.Id;
  Ev.Position := E.SpawnPosition;
  GameEventBus.Queue(Ev);

  if (FWorld <> nil) and (FFactory <> nil) then
    FWorld.RegisterEntity(FFactory.CreateEnemyEntity(E.Id));
end;

procedure TGameWorld.SpawnWave(const RoomIndex, Count: Integer; const Interval: Single);
var
  W: TSpawnWave;
begin
  W.EnemyCount := Count;
  W.Interval := Interval;
  W.Timer := 0;
  W.RoomIndex := RoomIndex;
  SetLength(FSpawnWaves, Length(FSpawnWaves) + 1);
  FSpawnWaves[High(FSpawnWaves)] := W;
end;

procedure TGameWorld.GenerateDungeon;
var
  i, j, k, Target: Integer;
  R: TDungeonRoom;
  AlreadyConnected: Boolean;
begin
  FData.Rooms := nil;
  SetLength(FData.Rooms, GlobalConfig.RoomCount);

  for i := 0 to GlobalConfig.RoomCount - 1 do
  begin
    R.Bounds.Left := (i mod 4) * GlobalConfig.RoomSize;
    R.Bounds.Bottom := (i div 4) * GlobalConfig.RoomSize;
    R.Bounds.Width := GlobalConfig.RoomSize - 2;
    R.Bounds.Height := GlobalConfig.RoomSize - 2;

    if i = 0 then
      R.RoomType := rtSpawn
    else if i = GlobalConfig.RoomCount - 1 then
      R.RoomType := rtExtraction
    else if Random < 0.15 then
      R.RoomType := rtBoss
    else
      R.RoomType := rtNormal;

    R.Connections := nil;
    for j := 0 to GlobalConfig.ConnectionsPerRoom - 1 do
    begin
      Target := Random(GlobalConfig.RoomCount);
      if Target = i then
        Continue;

      AlreadyConnected := False;
      for k := 0 to High(R.Connections) do
        if R.Connections[k] = Target then
        begin
          AlreadyConnected := True;
          Break;
        end;
      if AlreadyConnected then
        Continue;

      SetLength(R.Connections, Length(R.Connections) + 1);
      R.Connections[High(R.Connections)] := Target;
    end;

    FData.Rooms[i] := R;
  end;

  SetLength(FData.ExtractionPoints, 1);
  FData.ExtractionPoints[0].X := FData.Rooms[GlobalConfig.RoomCount - 1].Bounds.Left + FData.Rooms[GlobalConfig.RoomCount - 1].Bounds.Width / 2;
  FData.ExtractionPoints[0].Y := FData.Rooms[GlobalConfig.RoomCount - 1].Bounds.Bottom + FData.Rooms[GlobalConfig.RoomCount - 1].Bounds.Height / 2;
end;

function TGameWorld.GetData: TGameWorldData;
begin
  Result := FData;
end;

{ Игровой цикл }

function TGameWorld.FindClosestPlayer(const FromPos: TVector2; out Dist: Single): Integer;
var
  i: Integer;
  D: Single;
  Pos: TVector2;
begin
  Result := -1;
  Dist := 1e10;
  for i := 0 to High(FData.Players) do
  begin
    if FData.Players[i].Status <> psInRaid then
      Continue;
    if FData.Players[i].Visual = nil then
      Continue;
    Pos := FData.Players[i].Visual.Position;
    D := Sqr(Pos.X - FromPos.X) + Sqr(Pos.Y - FromPos.Y);
    if D < Dist then
    begin
      Dist := D;
      Result := i;
    end;
  end;
  if Result <> -1 then
    Dist := Sqrt(Dist);
end;

function TGameWorld.FindAlivePlayer(const FromPos: TVector2; ExcludeId: TEntityId; out Dist: Single): Integer;
var
  i: Integer;
  D: Single;
  Pos: TVector2;
begin
  Result := -1;
  Dist := 1e10;
  for i := 0 to High(FData.Players) do
  begin
    if FData.Players[i].Status <> psInRaid then
      Continue;
    if FData.Players[i].Id = ExcludeId then
      Continue;
    if FData.Players[i].Visual = nil then
      Continue;
    Pos := FData.Players[i].Visual.Position;
    D := Sqr(Pos.X - FromPos.X) + Sqr(Pos.Y - FromPos.Y);
    if D < Dist then
    begin
      Dist := D;
      Result := i;
    end;
  end;
  if Result <> -1 then
    Dist := Sqrt(Dist);
end;

procedure TGameWorld.UpdateAI(const SecondsPassed: Single);
var
  i, PlayerIdx: Integer;
  PlayerDist: Single;
  EnemyPos: TVector2;
  PlayerPos: TVector2;
begin
  for i := 0 to High(FData.Enemies) do
  begin
    if not FData.Enemies[i].Stats.IsAlive then
      Continue;
    if FData.Enemies[i].Visual = nil then
      Continue;
    EnemyPos := FData.Enemies[i].Visual.Position;

    PlayerIdx := FindClosestPlayer(EnemyPos, PlayerDist);
    if PlayerIdx = -1 then
      Continue;

    case FData.Enemies[i].AIState of
      asIdle:
        if PlayerDist <= FData.Enemies[i].DetectionRange then
          FData.Enemies[i].AIState := asChase;

      asPatrol:
        if PlayerDist <= FData.Enemies[i].DetectionRange then
          FData.Enemies[i].AIState := asChase;

      asChase:
      begin
        if PlayerDist > FData.Enemies[i].DetectionRange * 1.5 then
        begin
          FData.Enemies[i].AIState := asIdle;
          Continue;
        end;

        if PlayerDist <= FData.Enemies[i].AttackRange then
        begin
          FData.Enemies[i].AIState := asAttack;
          Continue;
        end;

        if FData.Players[PlayerIdx].Visual <> nil then
        begin
          PlayerPos := FData.Players[PlayerIdx].Visual.Position;
          EnemyPos.X := EnemyPos.X + (PlayerPos.X - EnemyPos.X) / PlayerDist *
            FData.Enemies[i].Stats.Speed * SecondsPassed;
          EnemyPos.Y := EnemyPos.Y + (PlayerPos.Y - EnemyPos.Y) / PlayerDist *
            FData.Enemies[i].Stats.Speed * SecondsPassed;
          FData.Enemies[i].Visual.Position := EnemyPos;
        end;
      end;

      asAttack:
      begin
        if PlayerDist > FData.Enemies[i].AttackRange * 1.2 then
          FData.Enemies[i].AIState := asChase;
      end;

      asDead:
        { ничего }
    end;
  end;
end;

procedure TGameWorld.UpdateCombat(const SecondsPassed: Single);
var
  i, PlayerIdx: Integer;
  PlayerDist: Single;
  DamageInfo: TDamageInfo;
  AliveCount: Integer;
  E: TGameEvent;
  EnemyPos: TVector2;
begin
  for i := 0 to High(FData.Enemies) do
  begin
    if FData.Enemies[i].AIState <> asAttack then
      Continue;
    if not FData.Enemies[i].Stats.IsAlive then
      Continue;
    if FData.Enemies[i].Visual = nil then
      Continue;

    EnemyPos := FData.Enemies[i].Visual.Position;
    PlayerIdx := FindClosestPlayer(EnemyPos, PlayerDist);
    if PlayerIdx = -1 then
      Continue;

    DamageInfo.Amount := FData.Enemies[i].Damage * SecondsPassed;
    DamageInfo.DamageType := dtPhysical;
    DamageInfo.SourceId := FData.Enemies[i].Id;
    FData.Players[PlayerIdx].Stats.TakeDamage(DamageInfo);

    if not FData.Players[PlayerIdx].Stats.IsAlive then
    begin
      FData.Players[PlayerIdx].Inventory.Free;
      FData.Players[PlayerIdx].Status := psDead;
      E.EventType := gePlayerDied;
      E.EntityId := FData.Players[PlayerIdx].Id;
      E.SourceId := FData.Enemies[i].Id;
      GameEventBus.Queue(E);
    end
    else
    begin
      E.EventType := gePlayerDamaged;
      E.EntityId := FData.Players[PlayerIdx].Id;
      E.SourceId := FData.Enemies[i].Id;
      E.Amount := DamageInfo.Amount;
      GameEventBus.Queue(E);
    end;
  end;
  AliveCount := 0;
  for i := 0 to High(FData.Enemies) do
  begin
    if FData.Enemies[i].Stats.IsAlive then
    begin
      if AliveCount <> i then
        FData.Enemies[AliveCount] := FData.Enemies[i];
      Inc(AliveCount);
    end
    else
    begin
      FData.Enemies[i].LootTable := nil;
    end;
  end;
  SetLength(FData.Enemies, AliveCount);
end;

procedure TGameWorld.UpdatePvP(const SecondsPassed: Single);
var
  i, TargetIdx: Integer;
  TargetDist: Single;
  DamageInfo: TDamageInfo;
  E: TGameEvent;
  MyPos: TVector2;
begin
  for i := 0 to High(FData.Players) do
  begin
    if FData.Players[i].Status <> psInRaid then
      Continue;
    if FData.Players[i].Visual = nil then
      Continue;

    MyPos := FData.Players[i].Visual.Position;
    TargetIdx := FindAlivePlayer(MyPos, FData.Players[i].Id, TargetDist);
    if TargetIdx = -1 then
      Continue;
    if TargetDist > FData.Players[i].AttackRange then
      Continue;

    DamageInfo.Amount := FData.Players[i].Damage * SecondsPassed;
    DamageInfo.DamageType := dtPhysical;
    DamageInfo.SourceId := FData.Players[i].Id;
    FData.Players[TargetIdx].Stats.TakeDamage(DamageInfo);

    if not FData.Players[TargetIdx].Stats.IsAlive then
    begin
      FData.Players[i].Kills := FData.Players[i].Kills + 1;
      FData.Players[TargetIdx].Inventory.Free;
      FData.Players[TargetIdx].Status := psDead;
      E.EventType := gePlayerDied;
      E.EntityId := FData.Players[TargetIdx].Id;
      E.SourceId := FData.Players[i].Id;
      GameEventBus.Queue(E);
    end
    else
    begin
      E.EventType := gePlayerDamaged;
      E.EntityId := FData.Players[TargetIdx].Id;
      E.SourceId := FData.Players[i].Id;
      E.Amount := DamageInfo.Amount;
      GameEventBus.Queue(E);
    end;
  end;
end;

procedure TGameWorld.UpdateExtraction(const SecondsPassed: Single);
var
  i: Integer;
  E: TGameEvent;
begin
  for i := 0 to High(FData.Players) do
  begin
    if FData.Players[i].Status <> psInRaid then
      Continue;
    if not FData.Players[i].IsExtracting then
      Continue;

    FData.Players[i].ExtractionProgress := FData.Players[i].ExtractionProgress +
      SecondsPassed / FExtractTime;

    if FData.Players[i].ExtractionProgress >= 1 then
    begin
      FData.Players[i].Status := psExtracted;
      E.EventType := gePlayerExtracted;
      E.EntityId := FData.Players[i].Id;
      GameEventBus.Queue(E);
    end;
  end;
end;

procedure TGameWorld.UpdateSpawner(const SecondsPassed: Single);
var
  i: Integer;
begin
  for i := High(FSpawnWaves) downto 0 do
  begin
    FSpawnWaves[i].Timer := FSpawnWaves[i].Timer + SecondsPassed;

    while (FSpawnWaves[i].EnemyCount > 0) and
          (FSpawnWaves[i].Timer >= FSpawnWaves[i].Interval) do
    begin
      SpawnEnemy(FSpawnWaves[i].RoomIndex);
      FSpawnWaves[i].Timer := FSpawnWaves[i].Timer - FSpawnWaves[i].Interval;
      Dec(FSpawnWaves[i].EnemyCount);
    end;

    if FSpawnWaves[i].EnemyCount <= 0 then
    begin
      if i < High(FSpawnWaves) then
        FSpawnWaves[i] := FSpawnWaves[High(FSpawnWaves)];
      SetLength(FSpawnWaves, Length(FSpawnWaves) - 1);
    end;
  end;
end;

end.
