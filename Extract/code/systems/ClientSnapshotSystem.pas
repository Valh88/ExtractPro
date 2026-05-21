unit ClientSnapshotSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Math,
  WorldSystemBase, GameWorld, NetMessages,
  help_types, Interfaces,
  PlayerInterpolationBehavior;

type
  TSnapshotFrame = record
    Time: Single;
    Entries: array of TSnapshotEntry;
  end;

  TClientSnapshotSystem = class(TWorldSystemBase)
  private
    FPrevSnap: TSnapshotFrame;
    FCurrSnap: TSnapshotFrame;
    FHavePrev: Boolean;
    FPrevTime: Single;
    FInterpStart: Single;
    FTime: Single;
    FLocalPlayerId: TEntityId;
    function FindEntry(const Entries: array of TSnapshotEntry; EntityId: UInt32): Integer;
    function LerpAngle(A, B, T: Single): Single;
  public
    procedure SetLocalPlayerId(const AId: TEntityId);
    procedure HandleSnapshot(const Data: TSnapshotData);
    procedure Update(const SecondsPassed: Single); override;
  end;

implementation

{ TClientSnapshotSystem }

procedure TClientSnapshotSystem.SetLocalPlayerId(const AId: TEntityId);
begin
  FLocalPlayerId := AId;
end;

function TClientSnapshotSystem.FindEntry(const Entries: array of TSnapshotEntry; EntityId: UInt32): Integer;
begin
  for Result := 0 to High(Entries) do
    if Entries[Result].EntityId = EntityId then Exit;
  Result := -1;
end;

function TClientSnapshotSystem.LerpAngle(A, B, T: Single): Single;
var
  Diff: Single;
begin
  Diff := B - A;
  if Diff > Pi then Diff := Diff - 2 * Pi;
  if Diff < -Pi then Diff := Diff + 2 * Pi;
  Result := A + Diff * T;
end;

procedure TClientSnapshotSystem.HandleSnapshot(const Data: TSnapshotData);
var
  I: Integer;
  Entry: TSnapshotEntry;
  Entity: IGameEntity;
  Interp: TPlayerInterpolation;
  InitPos: help_types.TVector3;
begin
  FPrevSnap := FCurrSnap;
  FPrevTime := FCurrSnap.Time;
  FHavePrev := FCurrSnap.Entries <> nil;

  FCurrSnap.Time := FTime;
  FCurrSnap.Entries := Copy(Data.Entries, 0, Length(Data.Entries));
  FInterpStart := FTime;

  for I := 0 to High(Data.Entries) do
  begin
    Entry := Data.Entries[I];
    if Entry.EntityId = FLocalPlayerId then Continue;

    Entity := WorldObj.FindEntity(Entry.EntityId);
    if Entity = nil then
    begin
      if Entry.EntityType = 0 then
      begin
        Entity := WorldObj.Factory.CreatePlayerEntity(Entry.EntityId);
        if Entity.Transform.RigidBody <> nil then
        begin
          Entity.Transform.RigidBody.Dynamic := False;
          Entity.Transform.RigidBody.Animated := True;
        end;
        WorldObj.AddPlayer(Entity);
      end;
      if Entity = nil then Continue;
    end;

    Interp := Entity.Transform.FindBehavior(TPlayerInterpolation) as TPlayerInterpolation;
    if Interp = nil then
    begin
      Interp := TPlayerInterpolation.Create(Entity.Transform);
      Entity.Transform.AddBehavior(Interp);
    end;

    if not FHavePrev then
    begin
      Interp.SetTarget(Entry.PosX, Entry.PosY, Entry.PosZ, Entry.RotY);
      InitPos.X := Entry.PosX; InitPos.Y := Entry.PosY; InitPos.Z := Entry.PosZ;
      Entity.Position3 := InitPos;
    end;
  end;
end;

procedure TClientSnapshotSystem.Update(const SecondsPassed: Single);
var
  I, J: Integer;
  Entry, PrevEntry: TSnapshotEntry;
  Entity: IGameEntity;
  Interp: TPlayerInterpolation;
  Duration, T: Single;
  LerpX, LerpY, LerpZ, LerpRot: Single;
begin
  FTime := FTime + SecondsPassed;

  if FCurrSnap.Entries = nil then Exit;

  if not FHavePrev then
  begin
    for I := 0 to High(FCurrSnap.Entries) do
    begin
      Entry := FCurrSnap.Entries[I];
      if Entry.EntityId = FLocalPlayerId then Continue;
      Entity := WorldObj.FindEntity(Entry.EntityId);
      if Entity = nil then Continue;
      Interp := Entity.Transform.FindBehavior(TPlayerInterpolation) as TPlayerInterpolation;
      if Interp <> nil then
        Interp.SetTarget(Entry.PosX, Entry.PosY, Entry.PosZ, Entry.RotY);
    end;
    Exit;
  end;

  Duration := FCurrSnap.Time - FPrevTime;
  if Duration > 0 then
    T := (FTime - FInterpStart) / Duration
  else
    T := 1.0;
  T := EnsureRange(T, 0.0, 1.0);

  for I := 0 to High(FCurrSnap.Entries) do
  begin
    Entry := FCurrSnap.Entries[I];
    if Entry.EntityId = FLocalPlayerId then Continue;

    Entity := WorldObj.FindEntity(Entry.EntityId);
    if Entity = nil then Continue;

    Interp := Entity.Transform.FindBehavior(TPlayerInterpolation) as TPlayerInterpolation;
    if Interp = nil then Continue;

    J := FindEntry(FPrevSnap.Entries, Entry.EntityId);
    if J >= 0 then
    begin
      PrevEntry := FPrevSnap.Entries[J];
      LerpX := PrevEntry.PosX + (Entry.PosX - PrevEntry.PosX) * T;
      LerpY := PrevEntry.PosY + (Entry.PosY - PrevEntry.PosY) * T;
      LerpZ := PrevEntry.PosZ + (Entry.PosZ - PrevEntry.PosZ) * T;
      LerpRot := LerpAngle(PrevEntry.RotY, Entry.RotY, T);
      Interp.SetTarget(LerpX, LerpY, LerpZ, LerpRot);
    end else
      Interp.SetTarget(Entry.PosX, Entry.PosY, Entry.PosZ, Entry.RotY);
  end;
end;

end.
