unit ServerSnapshotSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  WorldSystemBase, GameWorld, NetMessages, NetServer,
  EntityTypes,
  CastleTransform, CastleVectors, CastleLog,
  ServerPlayerSyncBehavior;

type
  TServerSnapshotSystem = class(TWorldSystemBase)
  private
    FServer: TGameServer;
    FTimer: Single;
    FSeq: UInt32;
    FServerTime: Double;

  public
    constructor Create(AWorldObj: TGameWorld; AServer: TGameServer);
    procedure Update(const SecondsPassed: Single); override;
  end;

implementation

{ TServerSnapshotSystem }

constructor TServerSnapshotSystem.Create(AWorldObj: TGameWorld; AServer: TGameServer);
begin
  inherited Create(AWorldObj);
  FServer := AServer;
  FTimer := 0;
  FSeq := 0;
  FServerTime := 0;
end;

procedure TServerSnapshotSystem.Update(const SecondsPassed: Single);
var
  Snap: TSnapshotData;
  M: TNetMessage;
  I, Cnt: Integer;
  P: TPlayerData;
  E: TEnemyData;
  B: TBulletData;
  Entry: TSnapshotEntry;
  VisRoot: TCastleTransform;
  TmpI: Integer;
  Sync: TServerPlayerSync;
begin
  FServerTime := FServerTime + SecondsPassed;
  FTimer := FTimer + SecondsPassed;
  if FTimer < 1 / 30 then Exit;
  FTimer := 0;

  Snap.ServerTime := FServerTime;
  Snap.Seq := FSeq;
  Inc(FSeq);

  Cnt := 0;
  for I := 0 to High(WorldObj.Data.Players) do
    if WorldObj.Data.Players[I].Visual <> nil then
      Inc(Cnt);
  for I := 0 to High(WorldObj.Data.Enemies) do
    if WorldObj.Data.Enemies[I].Visual <> nil then
      Inc(Cnt);
  for I := 0 to High(WorldObj.Data.Bullets) do
    if WorldObj.Data.Bullets[I].Visual <> nil then
      Inc(Cnt);

  SetLength(Snap.Entries, Cnt);
  Cnt := 0;

  for I := 0 to High(WorldObj.Data.Players) do
  begin
    P := WorldObj.Data.Players[I];
    if P.Visual = nil then Continue;
    Entry.EntityId := P.Id;
    Entry.EntityType := 0;
    Entry.PosX := P.Visual.Position3.X;
    Entry.PosY := P.Visual.Position3.Y;
    Entry.PosZ := P.Visual.Position3.Z;
    Entry.RotY := P.Visual.Rotation;
    VisRoot := nil;
    for TmpI := 0 to P.Visual.Transform.Count - 1 do
      if P.Visual.Transform.Items[TmpI].Name = 'VisualRoot' then
      begin
        VisRoot := P.Visual.Transform.Items[TmpI];
        Break;
      end;
    if VisRoot <> nil then
      Entry.RotY := VisRoot.Rotation.W
    else
      Entry.RotY := P.Visual.Transform.Rotation.W;
    Entry.Pitch := 0;
    Sync := P.Visual.Transform.FindBehavior(TServerPlayerSync) as TServerPlayerSync;
    if Sync <> nil then
      Entry.Pitch := Sync.Pitch;
    Snap.Entries[Cnt] := Entry;
    Inc(Cnt);
  end;

  for I := 0 to High(WorldObj.Data.Enemies) do
  begin
    E := WorldObj.Data.Enemies[I];
    if E.Visual = nil then Continue;
    Entry.EntityId := E.Id;
    Entry.EntityType := 1;
    Entry.PosX := E.Visual.Position3.X;
    Entry.PosY := E.Visual.Position3.Y;
    Entry.PosZ := E.Visual.Position3.Z;
    Entry.RotY := E.Visual.Rotation;
    Snap.Entries[Cnt] := Entry;
    Inc(Cnt);
  end;

  for I := 0 to High(WorldObj.Data.Bullets) do
  begin
    B := WorldObj.Data.Bullets[I];
    if B.Visual = nil then Continue;
    Entry.EntityId := B.Id;
    Entry.EntityType := 2;
    Entry.PosX := B.Visual.Position3.X;
    Entry.PosY := B.Visual.Position3.Y;
    Entry.PosZ := B.Visual.Position3.Z;
    Entry.RotY := B.Visual.Rotation;
    Snap.Entries[Cnt] := Entry;
    Inc(Cnt);
  end;

  M.Init(msgSnapshot, Snap.ToBytes);
  FServer.Broadcast(M);
end;

end.
