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
  CastleTransform, CastleScene, CastleVectors,
  help_types, Interfaces, EntityBridge;

type
  { Фабрика для headless-сервера: создаёт сущности с физикой, без визуала, камер и управлений }
  TServerEntityFactory = class(TInterfacedObject, IEntityFactory)
  private
    FPlayerUrl: String;
    FEnemyUrl: String;
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

function TServerEntityFactory.CreateEntity(const AEntityId: TEntityId;
  const AUrl: String): IGameEntity;
var
  Design: TCastleTransformDesign;
begin
  Design := TCastleTransformDesign.Create(nil);
  Design.Url := AUrl;
  Result := TEntityBridge.Create(AEntityId, Design);
end;

function TServerEntityFactory.CreatePlayerEntity(const AEntityId: TEntityId): IGameEntity;
begin
  Result := CreateEntity(AEntityId, FPlayerUrl);
end;

function TServerEntityFactory.CreateMainPlayerEntity(const AEntityId: TEntityId): IGameEntity;
begin
  Result := CreateEntity(AEntityId, FPlayerUrl);
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
begin
  //Заглушка
  Result := CreateEnemyEntity(AEntityId);
end;

end.
