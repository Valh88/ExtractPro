unit ExtractPointSystem;

{$mode objfpc}{$H+}

interface

uses
  CastleTransform, CastleLog,
  GameWorld, WorldSystemBase, EventBus, EntityTypes, help_types,
  ExtractPointTriggerBehavior;

type
  { Серверная система зоны эвакуации (ExtractPoint).
    Вешает физический триггер на зону (поведение TExtractPointTriggerBehavior),
    транслирует вход/выход игроков в события шины (geExtractZoneEntered/Exited).
    Вся дальнейшая игровая логика эвакуации будет здесь. }
  TExtractPointSystem = class(TWorldSystemBase)
  private
    FWorldRoot: TCastleAbstractRootTransform;
    FExtractPointHookDone: Boolean;
    function FindNodeByName(const ARoot: TCastleTransform; const AName: String): TCastleTransform;
    procedure AttachExtractPointBehavior;
    procedure OnExtractPointEnter(const AOtherTransform: TCastleTransform);
    procedure OnExtractPointExit(const AOtherTransform: TCastleTransform);
    function PlayerEntityIdByTransform(const ATransform: TCastleTransform): TEntityId;
  public
    constructor Create(AWorldObj: TGameWorld; const AWorldRoot: TCastleAbstractRootTransform);
    procedure Update(const SecondsPassed: Single); override;
  end;

implementation

{ TExtractPointSystem }

constructor TExtractPointSystem.Create(AWorldObj: TGameWorld;
  const AWorldRoot: TCastleAbstractRootTransform);
begin
  inherited Create(AWorldObj);
  FWorldRoot := AWorldRoot;
end;

function TExtractPointSystem.FindNodeByName(const ARoot: TCastleTransform;
  const AName: String): TCastleTransform;
var
  I: Integer;
begin
  Result := nil;
  if ARoot = nil then
    Exit;
  if ARoot.Name = AName then
    Exit(ARoot);
  for I := 0 to ARoot.Count - 1 do
  begin
    Result := FindNodeByName(ARoot.Items[I], AName);
    if Result <> nil then
      Exit;
  end;
end;

procedure TExtractPointSystem.AttachExtractPointBehavior;
var
  Node, Target: TCastleTransform;
  B: TExtractPointTriggerBehavior;
begin
  if FExtractPointHookDone then
    Exit;
  Node := FindNodeByName(FWorldRoot, 'ExtractPoint');
  if Node = nil then
    Exit;
  if Node is TCastleTransformDesign then
    Target := TCastleTransformDesign(Node).DesignRoot
  else
    Target := Node;
  if Target = nil then
    Exit;
  B := TExtractPointTriggerBehavior.Create(nil);
  B.OnEnter := @OnExtractPointEnter;
  B.OnExit := @OnExtractPointExit;
  Target.AddBehavior(B);
  FExtractPointHookDone := True;
end;

function TExtractPointSystem.PlayerEntityIdByTransform(
  const ATransform: TCastleTransform): TEntityId;
var
  I: Integer;
begin
  if ATransform <> nil then
    for I := 0 to High(WorldObj.Data.Players) do
      if (WorldObj.Data.Players[I].Visual <> nil) and
         (WorldObj.Data.Players[I].Visual.Transform = ATransform) then
        Exit(WorldObj.Data.Players[I].Id);
  Result := 0;
end;

procedure TExtractPointSystem.OnExtractPointEnter(const AOtherTransform: TCastleTransform);
var
  Eid: TEntityId;
  Ev: TGameEvent;
begin
  Eid := PlayerEntityIdByTransform(AOtherTransform);
  if Eid = 0 then
    Exit;
  Ev.EventType := geExtractZoneEntered;
  Ev.EntityId := Eid;
  Ev.SourceId := 0;
  Ev.Amount := 0;
  Ev.Position.X := AOtherTransform.Translation.X;
  Ev.Position.Y := AOtherTransform.Translation.Z;
  Ev.Data := nil;
  WorldObj.QueueEvent(Ev);
  WritelnLog('Server', 'ExtractPoint: player (entity %d) entered zone', [Eid]);
end;

procedure TExtractPointSystem.OnExtractPointExit(const AOtherTransform: TCastleTransform);
var
  Eid: TEntityId;
  Ev: TGameEvent;
begin
  Eid := PlayerEntityIdByTransform(AOtherTransform);
  if Eid = 0 then
    Exit;
  Ev.EventType := geExtractZoneExited;
  Ev.EntityId := Eid;
  Ev.SourceId := 0;
  Ev.Amount := 0;
  Ev.Position.X := AOtherTransform.Translation.X;
  Ev.Position.Y := AOtherTransform.Translation.Z;
  Ev.Data := nil;
  WorldObj.QueueEvent(Ev);
  WritelnLog('Server', 'ExtractPoint: player (entity %d) left zone', [Eid]);
end;

procedure TExtractPointSystem.Update(const SecondsPassed: Single);
begin
  if not FExtractPointHookDone then
    AttachExtractPointBehavior;
end;

end.
