unit GameWorld;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, help_types, EntityTypes, WorldTypes, GameConfig, Interfaces, EventBus,
  CastleKeysMouse;

type
  TRaidPhase = (rpExploring, rpExtracting);

  TGameWorld = class
  private
    FData: TGameWorldData;
    FPhase: TRaidPhase;
    FNextEntityId: TEntityId;
    FMaxRaidTime: Single;
    FWorld: IGameWorld;
    FFactory: IEntityFactory;
    FDeadEntities: array of TEntityId;
    FEventBus: TEventBus;

    function FindPlayerIndex(const AEntityId: TEntityId): Integer;
    function FindEnemyIndex(const AEntityId: TEntityId): Integer;
    procedure FlushDeadEntities;
  protected
    FSystems: array of IWorldSystem;
    procedure RegisterSystems; virtual;
    procedure AddSystem(ASystem: IWorldSystem);
  public
    constructor Create(AWorld: IGameWorld; AFactory: IEntityFactory);
    destructor Destroy; override;

    function AllocateEntityId: TEntityId;
    function Press(const Event: TInputPressRelease): Boolean; virtual;
    procedure HandleJoinAccept(const AEntityId: TEntityId; const APosX, APosY, APosZ, ARotY: Single); virtual;
    procedure Start; virtual;
    procedure Stop; virtual;
    procedure Update(const SecondsPassed: Single); virtual;

    { Управление миром }
    procedure AddPlayer(const AVisual: IGameEntity);
    procedure AddBullet(const AVisual: IGameEntity; const AOwnerId: TEntityId);
    procedure SpawnEnemy(const RoomIndex: Integer);
    procedure GenerateDungeon;
    procedure StartExtraction;
    function GetData: TGameWorldData;
    procedure SetEntityVisual(const AEntityId: TEntityId; const Visual: IGameEntity);
    procedure RemoveEntity(const AEntityId: TEntityId);

    { Доступ для систем }
    property Data: TGameWorldData read FData;
    function FindEntity(const AEntityId: TEntityId): IGameEntity;
    function FindClosestPlayer(const FromPos: TVector2; out Dist: Single): Integer;
    function FindAlivePlayer(const FromPos: TVector2; ExcludeId: TEntityId; out Dist: Single): Integer;
    procedure QueueEvent(const Ev: TGameEvent);
    procedure QueueDeadEntity(const AEntityId: TEntityId);

    property Phase: TRaidPhase read FPhase;
    property World: IGameWorld read FWorld write FWorld;
    property Factory: IEntityFactory read FFactory write FFactory;
  end;

  TGameWorldClass = class of TGameWorld;

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

  RegisterSystems;
  FEventBus := TEventBus.Create;
end;

destructor TGameWorld.Destroy;
begin
  FWorld := nil;
  FSystems := nil;
  FData.Free;
  FFactory := nil;
  FEventBus.Free;
  inherited;
end;

procedure TGameWorld.RegisterSystems;
begin
end;

procedure TGameWorld.AddSystem(ASystem: IWorldSystem);
begin
  SetLength(FSystems, Length(FSystems) + 1);
  FSystems[High(FSystems)] := ASystem;
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
  P.Id := AEntityId; //TODO удалить это в будущем, заглушка
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
    Exit;
  end;
  Last := High(FData.Bullets);
  for Idx := 0 to Last do
    if FData.Bullets[Idx].Id = AEntityId then
    begin
      FData.Bullets[Idx].Visual := nil;
      if Idx < Last then
        FData.Bullets[Idx] := FData.Bullets[Last];
      SetLength(FData.Bullets, Last);
      Exit;
    end;
end;

{ IGameWorld }

procedure TGameWorld.Start;
begin
  FPhase := rpExploring;
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
  for i := 0 to High(FSystems) do
    FSystems[i].Update(SecondsPassed);

  FEventBus.Flush;
  FlushDeadEntities;
end;

function TGameWorld.Press(const Event: TInputPressRelease): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(FSystems) do
    if FSystems[i].Press(Event) then Exit(True);
end;

procedure TGameWorld.HandleJoinAccept(const AEntityId: TEntityId; const APosX, APosY, APosZ, ARotY: Single);
begin
end;

procedure TGameWorld.QueueEvent(const Ev: TGameEvent);
begin
  FEventBus.Queue(Ev);
end;

procedure TGameWorld.QueueDeadEntity(const AEntityId: TEntityId);
var
  L: Integer;
begin
  L := Length(FDeadEntities);
  SetLength(FDeadEntities, L + 1);
  FDeadEntities[L] := AEntityId;
end;

procedure TGameWorld.FlushDeadEntities;
var
  Id: TEntityId;
begin
  for Id in FDeadEntities do
  begin
    if FWorld <> nil then
      FWorld.UnregisterEntity(Id);
    RemoveEntity(Id);
  end;
  FDeadEntities := nil;
end;

procedure TGameWorld.AddPlayer(const AVisual: IGameEntity);
var
  P: TPlayerData;
begin
  P.Id := AVisual.EntityId;
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
  P.Visual := AVisual;

  SetLength(FData.Players, Length(FData.Players) + 1);
  FData.Players[High(FData.Players)] := P;

  if (FWorld <> nil) then
  begin
    FWorld.RegisterEntity(AVisual);
  end;
end;

procedure TGameWorld.AddBullet(const AVisual: IGameEntity; const AOwnerId: TEntityId);
var
  B: TBulletData;
begin
  B.Id := AVisual.EntityId;
  B.OwnerId := AOwnerId;
  B.Visual := AVisual;

  SetLength(FData.Bullets, Length(FData.Bullets) + 1);
  FData.Bullets[High(FData.Bullets)] := B;

  if (FWorld <> nil) then
    FWorld.RegisterEntity(AVisual);
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
  FEventBus.Queue(Ev);

  if (FWorld <> nil) and (FFactory <> nil) then
    FWorld.RegisterEntity(FFactory.CreateEnemyEntity(E.Id));
end;

procedure TGameWorld.GenerateDungeon;
begin
  FData.ExtractionPoints := nil;
  FData.Rooms := nil;
end;

function TGameWorld.GetData: TGameWorldData;
begin
  Result := FData;
end;

{ Игровой цикл }

function TGameWorld.FindEntity(const AEntityId: TEntityId): IGameEntity;
var
  i: Integer;
begin
  for i := 0 to High(FData.Players) do
    if (FData.Players[i].Id = AEntityId) and (FData.Players[i].Visual <> nil) then
      Exit(FData.Players[i].Visual);
  for i := 0 to High(FData.Enemies) do
    if (FData.Enemies[i].Id = AEntityId) and (FData.Enemies[i].Visual <> nil) then
      Exit(FData.Enemies[i].Visual);
  for i := 0 to High(FData.Bullets) do
    if (FData.Bullets[i].Id = AEntityId) and (FData.Bullets[i].Visual <> nil) then
      Exit(FData.Bullets[i].Visual);
  Result := nil;
end;

function TGameWorld.FindClosestPlayer(const FromPos: TVector2; out Dist: Single): Integer;
var
  i: Integer;
  D: Single;
  P: TVector3;
begin
  Result := -1;
  Dist := 1e10;
  for i := 0 to High(FData.Players) do
  begin
    if FData.Players[i].Status <> psInRaid then
      Continue;
    if FData.Players[i].Visual = nil then
      Continue;
    P := FData.Players[i].Visual.Position3;
    D := Sqr(P.X - FromPos.X) + Sqr(P.Y - FromPos.Y);
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
  P: TVector3;
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
    P := FData.Players[i].Visual.Position3;
    D := Sqr(P.X - FromPos.X) + Sqr(P.Y - FromPos.Y);
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
