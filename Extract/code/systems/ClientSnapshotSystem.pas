unit ClientSnapshotSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  WorldSystemBase, GameWorld, NetMessages,
  help_types, Interfaces;

type
  TClientSnapshotSystem = class(TWorldSystemBase)
  private
    FLocalPlayerId: TEntityId;
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

procedure TClientSnapshotSystem.HandleSnapshot(const Data: TSnapshotData);
var
  I: Integer;
  Entry: TSnapshotEntry;
  Entity: IGameEntity;
  Pos: help_types.TVector3;
begin
  for I := 0 to High(Data.Entries) do
  begin
    Entry := Data.Entries[I];
    if Entry.EntityId = FLocalPlayerId then Continue;

    Entity := WorldObj.FindEntity(Entry.EntityId);
    if Entity <> nil then
    begin
      Pos.X := Entry.PosX; Pos.Y := Entry.PosY; Pos.Z := Entry.PosZ;
      Entity.Position3 := Pos;
      Entity.Rotation := Entry.RotY;
    end;
  end;
end;

procedure TClientSnapshotSystem.Update(const SecondsPassed: Single);
begin
end;

end.
