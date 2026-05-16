unit WorldBridge;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, CastleTransform, CastleVectors, CastleKeysMouse, CastleUIControls, help_types,
  Interfaces, GameWorld;

type
  TWorldBridge = class(TInterfacedObject, IGameWorld)
  private
    FRoot: TCastleAbstractRootTransform;
    FGameLogic: TGameWorld;
    FFactory: IEntityFactory;
  public
    constructor Create(const ARoot: TCastleAbstractRootTransform; const AFactory: IEntityFactory);
    destructor Destroy; override;

    property GameLogic: TGameWorld read FGameLogic;

    { IGameWorld }
    procedure Start;
    procedure Stop;
    procedure Resume;
    procedure Pause;
    procedure Update(const SecondsPassed: Single);
    function RayCast(const FromPoint, ToPoint: help_types.TVector3; out ResultData: TRayCastResult): Boolean;
    procedure RegisterEntity(Entity: IGameEntity);
    procedure UnregisterEntity(EntityId: TEntityId);
    function FindEntity(EntityId: TEntityId): IGameEntity;
    function HasEntity(EntityId: TEntityId): Boolean;
    function Press(const Event: TInputPressRelease): Boolean;
  end;

implementation

{ TWorldBridge }

constructor TWorldBridge.Create(const ARoot: TCastleAbstractRootTransform; const AFactory: IEntityFactory);
begin
  inherited Create;
  FRoot := ARoot;
  FFactory := AFactory;
  FGameLogic := TGameWorld.Create(Self, AFactory);
end;

destructor TWorldBridge.Destroy;
var
  i: Integer;
begin
  if FGameLogic <> nil then
    FGameLogic.World := nil;

  if (FGameLogic <> nil) and (FRoot <> nil) then
  begin
    for i := 0 to High(FGameLogic.Data.Players) do
      if FGameLogic.Data.Players[i].Visual <> nil then
      begin
        FRoot.Remove(FGameLogic.Data.Players[i].Visual.Transform);
        FGameLogic.Data.Players[i].Visual := nil;
      end;
    for i := 0 to High(FGameLogic.Data.Enemies) do
      if FGameLogic.Data.Enemies[i].Visual <> nil then
      begin
        FRoot.Remove(FGameLogic.Data.Enemies[i].Visual.Transform);
        FGameLogic.Data.Enemies[i].Visual := nil;
      end;
  end;

  FGameLogic.Free;
  FFactory := nil;
  inherited;
end;

{ IGameWorld }

procedure TWorldBridge.Start;
begin
  FGameLogic.Start;

end;

procedure TWorldBridge.Stop;
begin
  FGameLogic.Stop;
end;

procedure TWorldBridge.Resume;
begin
end;

procedure TWorldBridge.Pause;
begin
end;

procedure TWorldBridge.Update(const SecondsPassed: Single);
begin
  FGameLogic.Update(SecondsPassed);
end;

function TWorldBridge.RayCast(const FromPoint, ToPoint: help_types.TVector3; out ResultData: TRayCastResult): Boolean;
var
  Dir: CastleVectors.TVector3;
  Origin: CastleVectors.TVector3;
  HitTransform: TCastleTransform;
  T: TCastleTransform;
  Dist: Single;
  i: Integer;
begin
  Origin := CastleVectors.Vector3(FromPoint.X, FromPoint.Y, FromPoint.Z);
  Dir := CastleVectors.Vector3(ToPoint.X - FromPoint.X, ToPoint.Y - FromPoint.Y, ToPoint.Z - FromPoint.Z);
  HitTransform := FRoot.WorldRayCast(Origin, Dir, Dist);

  ResultData.Hit := HitTransform <> nil;
  if ResultData.Hit then
  begin
    ResultData.Point.X := HitTransform.Translation.X;
    ResultData.Point.Y := HitTransform.Translation.Y;
    ResultData.Distance := Dist;
    ResultData.Entity := nil;
    T := HitTransform;
    while T <> nil do
    begin
      for i := 0 to High(FGameLogic.Data.Players) do
        if (FGameLogic.Data.Players[i].Visual <> nil) and
           (FGameLogic.Data.Players[i].Visual.Transform = T) then
        begin
          ResultData.Entity := FGameLogic.Data.Players[i].Visual;
          Exit(True);
        end;
      for i := 0 to High(FGameLogic.Data.Enemies) do
        if (FGameLogic.Data.Enemies[i].Visual <> nil) and
           (FGameLogic.Data.Enemies[i].Visual.Transform = T) then
        begin
          ResultData.Entity := FGameLogic.Data.Enemies[i].Visual;
          Exit(True);
        end;
      T := T.Parent as TCastleTransform;
    end;
  end;
  Result := ResultData.Hit;
end;

procedure TWorldBridge.RegisterEntity(Entity: IGameEntity);
begin
  Entity.Transform.Exists := True;
  FRoot.Add(Entity.Transform);
  FGameLogic.SetEntityVisual(Entity.EntityId, Entity);
end;

procedure TWorldBridge.UnregisterEntity(EntityId: TEntityId);
var
  Entity: IGameEntity;
begin
  Entity := FindEntity(EntityId);
  if Entity <> nil then
  begin
    FRoot.Remove(Entity.Transform);
    FGameLogic.RemoveEntity(EntityId);
  end;
end;

function TWorldBridge.FindEntity(EntityId: TEntityId): IGameEntity;
var
  i: Integer;
begin
  for i := 0 to High(FGameLogic.Data.Players) do
    if (FGameLogic.Data.Players[i].Visual <> nil) and
       (FGameLogic.Data.Players[i].Visual.EntityId = EntityId) then
      Exit(FGameLogic.Data.Players[i].Visual);
  for i := 0 to High(FGameLogic.Data.Enemies) do
    if (FGameLogic.Data.Enemies[i].Visual <> nil) and
       (FGameLogic.Data.Enemies[i].Visual.EntityId = EntityId) then
      Exit(FGameLogic.Data.Enemies[i].Visual);
  Result := nil;
end;

function TWorldBridge.HasEntity(EntityId: TEntityId): Boolean;
begin
  Result := FindEntity(EntityId) <> nil;
end;

function TWorldBridge.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := FGameLogic.Press(Event);
end;

end.
