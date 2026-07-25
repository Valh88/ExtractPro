unit ClientPlayerSyncBehavior;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes, Math,
  CastleTransform, CastleVectors,
  NetMessages, BehaviorBase;

type
  TSendMessageProc = reference to procedure(const Msg: TNetMessage; const AChannel: Integer);

  TClientPlayerSync = class(TBehaviorBase)
  private
    FSendProc: TSendMessageProc;
    FMyEntityId: UInt32;
    FStateTimer: Single;
  public
    constructor Create(AOwner: TComponent; AMyEntityId: UInt32; ASendProc: TSendMessageProc); reintroduce;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
  end;

implementation

{ TClientPlayerSync }

constructor TClientPlayerSync.Create(AOwner: TComponent; AMyEntityId: UInt32; ASendProc: TSendMessageProc);
begin
  inherited Create(AOwner);
  FMyEntityId := AMyEntityId;
  FSendProc := ASendProc;
  FStateTimer := 0;
end;

procedure TClientPlayerSync.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
var
  PState: TPlayerStateData;
  M: TNetMessage;
  VisRoot: TCastleTransform;
  I: Integer;
begin
  inherited Update(SecondsPassed, RemoveMe);
  RemoveMe := rtNone;

  if Parent = nil then Exit;

  FStateTimer := FStateTimer + SecondsPassed;
  if FStateTimer >= 0.05 then
  begin
    PState.EntityId := FMyEntityId;
    PState.PosX := Parent.Translation.X;
    PState.PosY := Parent.Translation.Y;
    PState.PosZ := Parent.Translation.Z;
    VisRoot := nil;
    for I := 0 to Parent.Count - 1 do
      if Parent.Items[I].Name = 'VisualRoot' then
      begin
        VisRoot := Parent.Items[I];
        Break;
      end;
    if VisRoot <> nil then
      PState.RotY := VisRoot.Rotation.W
    else
      PState.RotY := ArcTan2(Parent.Direction.X, -Parent.Direction.Z);
    M.Init(msgPlayerState, PState.ToBytes);
    if Assigned(FSendProc) then
      FSendProc(M, NET_CH_UNRELIABLE);
    FStateTimer := 0;
  end;
end;

end.
