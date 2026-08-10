{
  ServerEntityFactory.pas — фабрика IGameEntity для headless-сервера.

  ┌─────────────────────────────────────────────────────────────────────┐
  │  Создаёт TCastleTransformDesign из .castle-transform файлов.        │
  │  В отличие от TEntityManager (клиентская фабрика):                 │
  │    - НЕ требует TCastleViewport                                    │
  │    - НЕ создаёт TCharacterControllerBehavior                       │
  │    - НЕ создаёт TFirstPersonCameraBehavior                         │
  │    - НЕ создаёт головную камеру (HeadCamera)                       │
  │    - НЕ настраивает MouseLook                                      │
  │                                                                     │
  │  Игроки: загружает PlayerProto.castle-transform как есть            │
  │          (цилиндр + капсула-коллайдер + RigidBody)                  │
  │                                                                     │
  │  Враги: загружает 3D-сцену по URL (TCastleScene)                   │
  │                                                                     │
  │  Используется TWorldBridge для регистрации сущностей в             │
  │  TCastleAbstractRootTransform — физика работает в headless.        │
  │                                                                     │
  │  Зависимости: CastleTransform, CastleScene, EntityBridge,           │
  │               help_types, Interfaces                                │
  └─────────────────────────────────────────────────────────────────────┘
}
unit ServerEntityFactory;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  CastleTransform, CastleScene, CastleVectors, CastleShapes,
  help_types, Interfaces, EntityBridge, BehaviorBase, BulletTimer;

type
  { Фабрика для headless-сервера: создаёт сущности с физикой, без визуала, камер и управлений }
  TServerEntityFactory = class(TInterfacedObject, IEntityFactory)
  private
    FPlayerUrl: String;
    FEnemyUrl: String;
    function CreateSimplePhysicsEntity(const AEntityId: TEntityId): IGameEntity;
  public
    constructor Create(const APlayerUrl, AEnemyUrl: String);
    function CreateEntity(const AEntityId: TEntityId;
      const AUrl: String): IGameEntity;
    function CreatePlayerEntity(const AEntityId: TEntityId): IGameEntity;
    function CreateMainPlayerEntity(const AEntityId: TEntityId): IGameEntity;
    function CreateEnemyEntity(const AEntityId: TEntityId): IGameEntity;
    function CreateBulletEntity(const AEntityId: TEntityId): IGameEntity;
  end;

implementation

{ TServerEntityFactory }

constructor TServerEntityFactory.Create(const APlayerUrl, AEnemyUrl: String);
begin
  inherited Create;
  FPlayerUrl := APlayerUrl;
  FEnemyUrl := AEnemyUrl;
end;

function TServerEntityFactory.CreateSimplePhysicsEntity(const AEntityId: TEntityId): IGameEntity;
var
  Root: TCastleTransform;
  RB: TCastleRigidBody;
  Collider: TCastleCapsuleCollider;
begin
  Root := TCastleTransform.Create(nil);
  RB := TCastleRigidBody.Create(Root);
  RB.Dynamic := True;
  Root.AddBehavior(RB);
  Collider := TCastleCapsuleCollider.Create(Root);
  Collider.Height := 0.9;
  Collider.Radius := 0.625;
  Root.AddBehavior(Collider);
  Result := TEntityBridge.Create(AEntityId, Root);
end;

function TServerEntityFactory.CreateEntity(const AEntityId: TEntityId;
  const AUrl: String): IGameEntity;
var
  Design: TCastleTransformDesign;
  Root: TCastleTransform;
begin
  Design := TCastleTransformDesign.Create(nil);
  Design.Url := AUrl;
  Root := Design.DesignRoot;
  if Root = nil then
    raise Exception.Create('DesignRoot is nil in ' + AUrl);
  Result := TEntityBridge.Create(AEntityId, Root, Design);
end;

function TServerEntityFactory.CreatePlayerEntity(const AEntityId: TEntityId): IGameEntity;
begin
  {$ifdef VISUAL}
  Result := CreateEntity(AEntityId, FPlayerUrl);
  {$else}
  Result := CreateSimplePhysicsEntity(AEntityId);
  {$endif}
  Result.Transform.Name := 'Player' + IntToStr(AEntityId);
  if Result.Transform.RigidBody <> nil then
  begin
    {$ifdef VISUAL}
    Result.Transform.RigidBody.LockRotation := [0, 1, 2];
    {$else}
    Result.Transform.RigidBody.LockRotation := [0, 2];
    {$endif}
  end;
end;

function TServerEntityFactory.CreateMainPlayerEntity(const AEntityId: TEntityId): IGameEntity;
begin
  Result := CreatePlayerEntity(AEntityId);
end;

function TServerEntityFactory.CreateEnemyEntity(const AEntityId: TEntityId): IGameEntity;
var
  Scene: TCastleScene;
begin
  Scene := TCastleScene.Create(nil);
  Scene.Url := FEnemyUrl;
  Result := TEntityBridge.Create(AEntityId, Scene);
end;

function TServerEntityFactory.CreateBulletEntity(const AEntityId: TEntityId): IGameEntity;
var
  BulletRoot: TCastleTransform;
  RB: TCastleRigidBody;
  Collider: TCastleSphereCollider;
  Bullet: TBulletBehavior;
begin
  {$ifdef VISUAL}
  BulletRoot := TCastleSphere.Create(nil);
  TCastleSphere(BulletRoot).Radius := 0.15;
  TCastleSphere(BulletRoot).Color := Vector4(1, 0.8, 0, 1);
  {$else}
  BulletRoot := TCastleTransform.Create(nil);
  {$endif}

  RB := TCastleRigidBody.Create(BulletRoot);
  RB.Dynamic := True;
  RB.Gravity := False;

  Collider := TCastleSphereCollider.Create(BulletRoot);
  Collider.Radius := 0.15;

  BulletRoot.AddBehavior(RB);
  BulletRoot.AddBehavior(Collider);

  Bullet := TBulletBehavior.Create(BulletRoot, AEntityId);
  RB.OnCollisionEnter := @Bullet.OnCollision;
  BulletRoot.AddBehavior(Bullet);

  Result := TEntityBridge.Create(AEntityId, BulletRoot);
end;

end.
