unit GameWorldClient;

interface

uses
  SysUtils, GameWorld, ShotSystem, WorldBridge, CastleTransform, CastleViewport, CastleVectors,
  help_types, CastleKeysMouse, Interfaces, ClientNetSystem,
  MouseLookOverlay, FirstPersonCameraBehavior;

type
  TGameWorldClient = class(TGameWorld)
  protected
    FMainPlayerId: TEntityId;
    FViewport: TCastleViewport;
    FMouseLookUi: TMouseLookOverlay;
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
  Entity.Rotation := ARotY;
  AddPlayer(Entity);
  FMainPlayerId := Entity.EntityId;
  InitMainPlayerOverlay(Entity.Transform);
end;

procedure TGameWorldClient.RegisterSystems;
begin
  inherited;
  AddSystem(TShotSystem.Create(Self));
  AddSystem(TClientNetSystem.Create(Self));
end;

end.
