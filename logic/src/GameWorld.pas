unit GameWorld;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Contnrs, help_types, EntityTypes, WorldTypes, GameConfig, Interfaces, EventBus,
  WorldSystemBase, AISystem, CombatSystem, PvPSystem, ExtractionSystem, SpawnerSystem;

type
  TRaidPhase = (rpExploring, rpExtracting);

  TGameWorld = class
  private
    FData: TGameWorldData;
    FPhase: TRaidPhase;
    FNextEntityId: TEntityId;
    FRaidTime: Single;
    FMaxRaidTime: Single;
    FWorld: IGameWorld;
    FFactory: IEntityFactory;
    FSystems: TObjectList;
    FSpawner: TSpawnerSystem;

    function AllocateEntityId: TEntityId;
    function FindPlayerIndex(const AEntityId: TEntityId): Integer;
    function FindEnemyIndex(const AEntityId: TEntityId): Integer;
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

    { Доступ для систем }
    property Data: TGameWorldData read FData;
    function FindClosestPlayer(const FromPos: TVector2; out Dist: Single): Integer;
    function FindAlivePlayer(const FromPos: TVector2; ExcludeId: TEntityId; out Dist: Single): Integer;
    procedure QueueEvent(const Ev: TGameEvent);

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

  FSystems := TObjectList.Create(False);
  FSystems.Add(TAISystem.Create(Self));
  FSystems.Add(TCombatSystem.Create(Self));
  FSystems.Add(TPvPSystem.Create(Self));
  FSystems.Add(TExtractionSystem.Create(Self));
  FSpawner := TSpawnerSystem.Create(Self);
  FSystems.Add(FSpawner);
end;

destructor TGameWorld.Destroy;
begin
  FData.Free;
  FWorld := nil;
  FFactory := nil;
  FSystems.Free;
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

  for i := 0 to FSystems.Count - 1 do
    TWorldSystemBase(FSystems[i]).Update(SecondsPassed);

  GameEventBus.Flush;
end;

procedure TGameWorld.QueueEvent(const Ev: TGameEvent);
begin
  GameEventBus.Queue(Ev);
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
begin
  FSpawner.AddWave(RoomIndex, Count, Interval);
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

end.
