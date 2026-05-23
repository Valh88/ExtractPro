unit GameWorldClient;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, GameWorld, ShotSystem, WorldBridge, CastleTransform, CastleViewport, CastleVectors,
  help_types, CastleKeysMouse, Interfaces, ClientNetSystem,
  MouseLookOverlay, FirstPersonCameraBehavior,
  ClientSnapshotSystem, ClientOutbox, NetMessages, ClientPlayerSyncBehavior;

type
  TGameWorldClient = class(TGameWorld)
  protected
    FMainPlayerId: TEntityId;
    FViewport: TCastleViewport;
    FMouseLookUi: TMouseLookOverlay;
    FSnapSystem: TClientSnapshotSystem;
    FOutbox: TClientOutbox;
    procedure RegisterSystems; override;
  public
    constructor Create(const ARoot: TCastleAbstractRootTransform;
      const AFactory: IEntityFactory; const AViewport: TCastleViewport);
    destructor Destroy; override;
    procedure SpawnMainPlayer;
    procedure HandleJoinAccept(const AEntityId: TEntityId; const APosX, APosY, APosZ, ARotY: Single); override;
    procedure InitMainPlayerOverlay(const AHeroTransform: TCastleTransform);
    property MainPlayerId: TEntityId read FMainPlayerId write FMainPlayerId;
    property Viewport: TCastleViewport read FViewport write FViewport;
  end;

implementation

{ TGameWorldClient }

constructor TGameWorldClient.Create(const ARoot: TCastleAbstractRootTransform;
  const AFactory: IEntityFactory; const AViewport: TCastleViewport);
var
  B: TWorldBridge;
begin
  B := TWorldBridge.Create(ARoot);
  inherited Create(B as IGameWorld, AFactory);
  B.GameLogic := Self;
  FViewport := AViewport;
  FMouseLookUi := nil;
end;

destructor TGameWorldClient.Destroy;
begin
  FreeAndNil(FMouseLookUi);
  inherited;
end;

procedure TGameWorldClient.InitMainPlayerOverlay(const AHeroTransform: TCastleTransform);
begin
  if FMouseLookUi <> nil then
    FreeAndNil(FMouseLookUi);
  FMouseLookUi := TMouseLookOverlay.Create(FViewport.Owner);
  FMouseLookUi.FullSize := true;
  FMouseLookUi.Viewport := FViewport;
  FMouseLookUi.Hero := AHeroTransform;
  FViewport.InsertBack(FMouseLookUi);
end;

procedure TGameWorldClient.SpawnMainPlayer;
var
  Entity: IGameEntity;
begin
  Entity := Factory.CreateMainPlayerEntity(AllocateEntityId);
  AddPlayer(Entity);
  FMainPlayerId := Entity.EntityId;
  InitMainPlayerOverlay(Entity.Transform);

  Entity := Factory.CreatePlayerEntity(AllocateEntityId);
  AddPlayer(Entity);
end;

procedure TGameWorldClient.HandleJoinAccept(const AEntityId: TEntityId; const APosX, APosY, APosZ, ARotY: Single);
var
  Entity: IGameEntity;
begin
  Entity := Factory.CreateMainPlayerEntity(AEntityId);
  Entity.Transform.Translation := CastleVectors.Vector3(APosX, APosY, APosZ);
  // Entity.Rotation := ARotY; вращать роот или визуал?
  AddPlayer(Entity);
  FMainPlayerId := Entity.EntityId;
  InitMainPlayerOverlay(Entity.Transform);
end;

procedure TGameWorldClient.RegisterSystems;
var
  NetSys: TClientNetSystem;
  ShotSys: TShotSystem;
begin
  inherited;

  FOutbox := TClientOutbox.Create(Self);

  ShotSys := TShotSystem.Create(Self);
  ShotSys.Outbox := FOutbox;
  AddSystem(ShotSys);

  NetSys := TClientNetSystem.Create(Self);
  FSnapSystem := TClientSnapshotSystem.Create(Self);
  NetSys.SnapSystem := FSnapSystem;

  FOutbox.SendToProc := procedure(const M: TNetMessage; const AChannel: Integer)
  begin
    NetSys.SendToChannel(M, AChannel);
  end;

  NetSys.DefaultSendProc := procedure(const M: TNetMessage; const AChannel: Integer)
  begin
    FOutbox.Add(M, AChannel);
  end;

  AddSystem(NetSys);
  AddSystem(FSnapSystem);
  AddSystem(FOutbox);
end;

end.
