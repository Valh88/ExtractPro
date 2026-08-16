unit ClientSnapshotSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  WorldSystemBase, GameWorld, NetMessages,
  help_types, Interfaces,
  CastleTransform,
  PlayerInterpolationBehavior;

const
  SNAP_BUFFER_SIZE = 5;

type
  TSnapshotFrame = record
    ServerTime: Double;
    Entries: array of TSnapshotEntry;
  end;

  TClientSnapshotSystem = class(TWorldSystemBase)
  private
    FBuffer: array[0..SNAP_BUFFER_SIZE - 1] of TSnapshotFrame;
    FHead: Integer;
    FTail: Integer;
    FCount: Integer;
    FLocalPlayerId: TEntityId;
  public
    procedure SetLocalPlayerId(const AId: TEntityId);
    procedure HandleSnapshot(const Data: TSnapshotData);
    procedure Update(const SecondsPassed: Single); override;
    procedure ConfigureRemoteRigidBodies(const ATransform: TCastleTransform);
  end;

implementation

{ TClientSnapshotSystem }

procedure TClientSnapshotSystem.SetLocalPlayerId(const AId: TEntityId);
begin
  FLocalPlayerId := AId;
end;

procedure TClientSnapshotSystem.ConfigureRemoteRigidBodies(
  const ATransform: TCastleTransform);
var
  BList: TCastleBehaviorList;
  I: Integer;
begin
  if ATransform = nil then Exit;
  BList := ATransform.FindAllBehaviors(TCastleRigidBody);
  try
    for I := 0 to BList.Count - 1 do
    begin
      TCastleRigidBody(BList[I]).Dynamic := False;
      TCastleRigidBody(BList[I]).Animated := True;
    end;
  finally
    BList.Free;
  end;
end;

procedure TClientSnapshotSystem.HandleSnapshot(const Data: TSnapshotData);
var
  I: Integer;
  Entry: TSnapshotEntry;
  Entity: IGameEntity;
  Interp: TPlayerInterpolation;
begin
  FHead := (FHead + 1) mod SNAP_BUFFER_SIZE;
  FBuffer[FHead].ServerTime := Data.ServerTime;
  FBuffer[FHead].Entries := Copy(Data.Entries, 0, Length(Data.Entries));

  if FCount = SNAP_BUFFER_SIZE then
    FTail := (FTail + 1) mod SNAP_BUFFER_SIZE
  else
  begin
    Inc(FCount);
    if FCount = 1 then
      FTail := FHead;
  end;

  for I := 0 to High(Data.Entries) do
  begin
    Entry := Data.Entries[I];
    if Entry.EntityId = FLocalPlayerId then
      Continue;

    Entity := WorldObj.FindEntity(Entry.EntityId);
    if Entity = nil then
    begin
      if Entry.EntityType = 0 then
      begin
        Entity := WorldObj.Factory.CreatePlayerEntity(Entry.EntityId);
        ConfigureRemoteRigidBodies(Entity.Transform);
        WorldObj.AddPlayer(Entity);
      end;
      if Entity = nil then Continue;

      Interp := TPlayerInterpolation.Create(Entity.Transform);
      Entity.Transform.AddBehavior(Interp);
      Interp.SnapTo(Entry.PosX, Entry.PosY, Entry.PosZ, Entry.RotY, Entry.Pitch);
      Continue;
    end;

    Interp := Entity.Transform.FindBehavior(TPlayerInterpolation) as TPlayerInterpolation;
    if Interp = nil then
    begin
      Interp := TPlayerInterpolation.Create(Entity.Transform);
      Entity.Transform.AddBehavior(Interp);
      Interp.SnapTo(Entry.PosX, Entry.PosY, Entry.PosZ, Entry.RotY, Entry.Pitch);
    end
    else
      Interp.ApplyTarget(Entry.PosX, Entry.PosY, Entry.PosZ, Entry.RotY, Entry.Pitch);
  end;
end;

procedure TClientSnapshotSystem.Update(const SecondsPassed: Single);
begin
end;

end.
