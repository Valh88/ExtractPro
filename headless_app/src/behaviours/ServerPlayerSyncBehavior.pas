unit ServerPlayerSyncBehavior;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  CastleTransform, CastleVectors,
  NetMessages, BehaviorBase;

type
  TServerPlayerSync = class(TBehaviorBase)
  private
    FMyEntityId: UInt32;
    FVisRoot: TCastleTransform;
  public
    constructor Create(AOwner: TComponent; AMyEntityId: UInt32); reintroduce;
    procedure ApplyState(const State: TPlayerStateData);
    property MyEntityId: UInt32 read FMyEntityId;
  end;

implementation

{ TServerPlayerSync }

constructor TServerPlayerSync.Create(AOwner: TComponent; AMyEntityId: UInt32);
begin
  inherited Create(AOwner);
  FMyEntityId := AMyEntityId;
end;

procedure TServerPlayerSync.ApplyState(const State: TPlayerStateData);
var
  I: Integer;
begin
  if Parent = nil then Exit;

  Parent.Translation := CastleVectors.Vector3(State.PosX, State.PosY, State.PosZ);

  if FVisRoot = nil then
    for I := 0 to Parent.Count - 1 do
      if Parent.Items[I].Name = 'VisualRoot' then
      begin
        FVisRoot := Parent.Items[I];
        Break;
      end;

  if FVisRoot <> nil then
    FVisRoot.Rotation := CastleVectors.Vector4(0, 1, 0, State.RotY);
end;

end.
