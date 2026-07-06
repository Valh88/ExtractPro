unit EntityBridge;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Math, CastleScene, CastleTransform, CastleVectors, help_types, Interfaces, BehaviorBase;

type
  TEntityBridge = class(TInterfacedObject, IGameEntity)
  private
    FEntityId: TEntityId;
    FTransform: TCastleTransform;
    FOwner: TComponent;

    function GetEntityId: TEntityId;
    function GetTransform: TCastleTransform;
    function GetPosition3: help_types.TVector3;
    procedure SetPosition3(const Value: help_types.TVector3);
    function GetWorldPosition: help_types.TVector3;
    procedure SetWorldPosition(const Value: help_types.TVector3);
    function GetRotation: Single;
    procedure SetRotation(const Value: Single);
    function GetScale: Single;
    procedure SetScale(const Value: Single);
    function GetVisible: Boolean;
    procedure SetVisible(const Value: Boolean);
  public
    constructor Create(const AEntityId: TEntityId; const ATransform: TCastleTransform;
      const AOwner: TComponent = nil);
    destructor Destroy; override;

    { IGameEntity }
    property EntityId: TEntityId read GetEntityId;
    property Transform: TCastleTransform read GetTransform;
    property Position3: help_types.TVector3 read GetPosition3 write SetPosition3;
    property WorldPosition: help_types.TVector3 read GetWorldPosition write SetWorldPosition;
    property Rotation: Single read GetRotation write SetRotation;
    property Scale: Single read GetScale write SetScale;
    property Visible: Boolean read GetVisible write SetVisible;

    procedure AddBehavior(const ABehavior: TBehaviorBase);
    procedure RemoveBehavior(var ABehavior: TBehaviorBase);

    procedure PlayAnimation(const Name: String; Loop: Boolean);
    procedure StopAnimation;
    procedure SyncFromData(const EntityData: Pointer);
  end;

implementation

{ TEntityBridge }

constructor TEntityBridge.Create(const AEntityId: TEntityId; const ATransform: TCastleTransform;
  const AOwner: TComponent = nil);
begin
  inherited Create;
  FEntityId := AEntityId;
  FTransform := ATransform;
  FOwner := AOwner;
end;

destructor TEntityBridge.Destroy;
begin
  if FOwner <> nil then
    FreeAndNil(FOwner)
  else
    FreeAndNil(FTransform);
  inherited;
end;

function TEntityBridge.GetEntityId: TEntityId;
begin
  Result := FEntityId;
end;

function TEntityBridge.GetTransform: TCastleTransform;
begin
  Result := FTransform;
end;

function TEntityBridge.GetPosition3: help_types.TVector3;
begin
  Result.X := FTransform.Translation.X;
  Result.Y := FTransform.Translation.Y;
  Result.Z := FTransform.Translation.Z;
end;

procedure TEntityBridge.SetPosition3(const Value: help_types.TVector3);
begin
  FTransform.Translation := CastleVectors.Vector3(Value.X, Value.Y, Value.Z);
end;

function TEntityBridge.GetWorldPosition: help_types.TVector3;
begin
  Result.X := FTransform.WorldTranslation.X;
  Result.Y := FTransform.WorldTranslation.Y;
  Result.Z := FTransform.WorldTranslation.Z;
end;

procedure TEntityBridge.SetWorldPosition(const Value: help_types.TVector3);
begin
  FTransform.Translation := CastleVectors.Vector3(Value.X, Value.Y, Value.Z);
end;

function TEntityBridge.GetRotation: Single;
begin
  Result := ArcTan2(FTransform.Direction.X, -FTransform.Direction.Z);
end;

procedure TEntityBridge.SetRotation(const Value: Single);
begin
  FTransform.Rotation := CastleVectors.Vector4(0, 1, 0, Value);
end;

function TEntityBridge.GetScale: Single;
begin
  Result := FTransform.Scale.X;
end;

procedure TEntityBridge.SetScale(const Value: Single);
begin
  FTransform.Scale := CastleVectors.Vector3(Value, Value, 1);
end;

function TEntityBridge.GetVisible: Boolean;
begin
  Result := FTransform.Exists;
end;

procedure TEntityBridge.SetVisible(const Value: Boolean);
begin
  FTransform.Exists := Value;
end;

procedure TEntityBridge.PlayAnimation(const Name: String; Loop: Boolean);
begin
  if FTransform is TCastleScene then
    TCastleScene(FTransform).PlayAnimation(Name, Loop);
end;

procedure TEntityBridge.StopAnimation;
begin
end;

procedure TEntityBridge.SyncFromData(const EntityData: Pointer);
begin
end;

procedure TEntityBridge.AddBehavior(const ABehavior: TBehaviorBase);
begin
  if ABehavior = nil then Exit;
  ABehavior.Entity := Self;
  FTransform.AddBehavior(ABehavior);
end;

procedure TEntityBridge.RemoveBehavior(var ABehavior: TBehaviorBase);
begin
  if ABehavior = nil then Exit;
  ABehavior.Entity := nil;
  FTransform.RemoveBehavior(ABehavior);
  FreeAndNil(ABehavior);
end;

end.
