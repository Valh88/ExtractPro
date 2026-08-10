unit ExtractPointSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math,
  CastleTransform, CastleVectors, CastleLog,
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
    FAttachAttempts: Integer;
    FExtractZonePos: CastleVectors.TVector3;
    FExtractZoneTarget: TCastleTransform;
    FProximityTimer: Single;
    function FindNodeByName(const ARoot: TCastleTransform; const AName: String): TCastleTransform;
    procedure AttachExtractPointBehavior;
    procedure ValidateExtractPointHook;
    procedure LogClosestPlayerToExtractPoint;
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
  RB: TCastleRigidBody;
begin
  if FExtractPointHookDone then
    Exit;
  Node := FindNodeByName(FWorldRoot, 'ExtractPoint');
  if Node = nil then
  begin
    Inc(FAttachAttempts);
    if (FAttachAttempts mod 60 = 0) or (FAttachAttempts = 1) then
      WritelnLog('Server', 'ExtractPoint node not found (attempt %d, root children: %d)',
        [FAttachAttempts, FWorldRoot.Count]);
    Exit;
  end;
  if Node is TCastleTransformDesign then
    Target := TCastleTransformDesign(Node).DesignRoot
  else
    Target := Node;
  if Target = nil then
  begin
    WritelnLog('Server', 'ExtractPoint node "%s" found but DesignRoot is nil',
      [Node.Name]);
    Exit;
  end;
  RB := Target.FindBehavior(TCastleRigidBody) as TCastleRigidBody;
  B := TExtractPointTriggerBehavior.Create(nil);
  B.OnEnter := @OnExtractPointEnter;
  B.OnExit := @OnExtractPointExit;
  Target.AddBehavior(B);
  FExtractZonePos := Target.WorldTranslation;
  FExtractZoneTarget := Target;
  FExtractPointHookDone := True;
  WritelnLog('Server', 'ExtractPoint trigger attached (node=%s, target=%s, rb=%s, rb_exists=%s, collider=%s, pos=%s)',
    [Node.Name, Target.Name,
     BoolToStr(RB <> nil, True),
     BoolToStr((RB <> nil) and RB.Exists, True),
     BoolToStr(Target.Collider <> nil, True),
     FExtractZonePos.ToString]);
end;

procedure TExtractPointSystem.LogClosestPlayerToExtractPoint;
var
  I, ClosestIdx: Integer;
  Dist, MinDist: Single;
  P: help_types.TVector3;
begin
  if not FExtractPointHookDone then
    Exit;
  MinDist := -1;
  ClosestIdx := -1;
  for I := 0 to High(WorldObj.Data.Players) do
    if (WorldObj.Data.Players[I].Visual <> nil) and
       (WorldObj.Data.Players[I].Visual.Transform <> nil) then
    begin
      P := WorldObj.Data.Players[I].Visual.WorldPosition;
      Dist := Sqrt(Sqr(P.X - FExtractZonePos.X) + Sqr(P.Z - FExtractZonePos.Z));
      if (MinDist < 0) or (Dist < MinDist) then
      begin
        MinDist := Dist;
        ClosestIdx := I;
      end;
    end;
  if MinDist < 0 then
    WritelnLog('Server', 'ExtractZone: no players')
  else
    WritelnLog('Server', 'ExtractZone: closest player dist=%.1f, py=%.1f',
      [MinDist, WorldObj.Data.Players[ClosestIdx].Visual.WorldPosition.Y]);
end;

procedure TExtractPointSystem.ValidateExtractPointHook;
var
  P: TCastleTransform;
begin
  if not FExtractPointHookDone then
    Exit;
  if FExtractZoneTarget = nil then
  begin
    FExtractPointHookDone := False;
    Exit;
  end;
  P := FExtractZoneTarget;
  while (P <> nil) and (P <> TCastleTransform(FWorldRoot)) do
    P := P.Parent;
  if P = nil then
  begin
    WritelnLog('Server', 'ExtractPoint: target detached from world root, re-attaching');
    FExtractPointHookDone := False;
    FExtractZoneTarget := nil;
  end;
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
  FProximityTimer := FProximityTimer + SecondsPassed;
  if FProximityTimer >= 2.0 then
  begin
    FProximityTimer := FProximityTimer - 2.0;
    ValidateExtractPointHook;
    LogClosestPlayerToExtractPoint;
  end;
end;

end.
