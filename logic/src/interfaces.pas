unit Interfaces;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, CastleTransform, CastleKeysMouse, CastleUIControls, help_types;

type

  { Игровая сущность — мост между чистыми данными и TCastleTransform }
  IGameEntity = interface
    ['{D4E5F6A7-B8C9-0123-DEF0-1234567890AB}']
    function GetEntityId: TEntityId;
    property EntityId: TEntityId read GetEntityId;

    function GetTransform: TCastleTransform;
    property Transform: TCastleTransform read GetTransform;

    function GetPosition: TVector2;
    procedure SetPosition(const Value: TVector2);
    property Position: TVector2 read GetPosition write SetPosition;

    function GetRotation: Single;
    procedure SetRotation(const Value: Single);
    property Rotation: Single read GetRotation write SetRotation;

    function GetScale: Single;
    procedure SetScale(const Value: Single);
    property Scale: Single read GetScale write SetScale;

    function GetVisible: Boolean;
    procedure SetVisible(const Value: Boolean);
    property Visible: Boolean read GetVisible write SetVisible;

    procedure PlayAnimation(const Name: String; Loop: Boolean);
    procedure StopAnimation;
    procedure SyncFromData(const EntityData: Pointer);
  end;

  TRayCastResult = record
    Hit: Boolean;
    Point: TVector2;
    Normal: TVector2;
    Distance: Single;
    Entity: IGameEntity;
  end;

  { Основной интерфейс мира }
  IGameWorld = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    procedure Start;
    procedure Stop;
    procedure Resume;
    procedure Pause;
    procedure Update(const SecondsPassed: Single);
    function RayCast(const FromPoint, ToPoint: TVector3; out ResultData: TRayCastResult): Boolean;

    { Реестр сущностей }
    procedure RegisterEntity(Entity: IGameEntity);
    procedure UnregisterEntity(EntityId: TEntityId);
    function FindEntity(EntityId: TEntityId): IGameEntity;
    function HasEntity(EntityId: TEntityId): Boolean;
    function Press(const Event: TInputPressRelease): Boolean;
  end;

  { Фабрика визуалов — мост для создания IGameEntity внутри логики }
  IEntityFactory = interface
    ['{F1E2D3C4-B5A6-7890-ABCD-EF1234567890}']
    function CreateEntity(const AEntityId: TEntityId; const AUrl: String): IGameEntity;
    function CreatePlayerEntity(const AEntityId: TEntityId): IGameEntity;
    function CreateMainPlayerEntity(const AEntityId: TEntityId): IGameEntity;
    function CreateEnemyEntity(const AEntityId: TEntityId): IGameEntity;
    function CreateBulletEntity(const AEntityId: TEntityId): IGameEntity;
  end;

  { Базовая игровая система }
  IWorldSystem = interface
    ['{B1C2D3E4-F5A6-7890-BCDE-F0123456789A}']
    procedure Update(const SecondsPassed: Single);
  end;

implementation

end.
