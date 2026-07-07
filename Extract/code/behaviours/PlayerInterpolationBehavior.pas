unit PlayerInterpolationBehavior;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Math,
  CastleTransform, CastleVectors,
  BehaviorBase;

type
  TPlayerInterpolation = class(TBehaviorBase)
  private
    FTargetPos: TVector3;
    FTargetRot: Single;
    FVisRoot: TCastleTransform;
    FSmoothFactor: Single;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTarget(const AX, AY, AZ, ARotY: Single);
    procedure SnapTo(const AX, AY, AZ, ARotY: Single);
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    property SmoothFactor: Single read FSmoothFactor write FSmoothFactor;
  end;

implementation

{ TPlayerInterpolation }

constructor TPlayerInterpolation.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSmoothFactor := 20.0;
end;

procedure TPlayerInterpolation.ApplyTarget(const AX, AY, AZ, ARotY: Single);
begin
  FTargetPos := Vector3(AX, AY, AZ);
  FTargetRot := ARotY;
end;

procedure TPlayerInterpolation.SnapTo(const AX, AY, AZ, ARotY: Single);
var
  I: Integer;
begin
  FTargetPos := Vector3(AX, AY, AZ);
  FTargetRot := ARotY;

  if Parent = nil then Exit;
  Parent.Translation := FTargetPos;

  if FVisRoot = nil then
    for I := 0 to Parent.Count - 1 do
      if Parent.Items[I].Name = 'VisualRoot' then
      begin
        FVisRoot := Parent.Items[I];
        Break;
      end;

  if FVisRoot <> nil then
    FVisRoot.Rotation := Vector4(0, 1, 0, FTargetRot)
  else
    Parent.Rotation := Vector4(0, 1, 0, FTargetRot);
end;

procedure TPlayerInterpolation.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
var
  K, Diff, CurrRot: Single;
  I: Integer;
begin
  inherited Update(SecondsPassed, RemoveMe);
  RemoveMe := rtNone;

  if Parent = nil then Exit;

  if FVisRoot = nil then
    for I := 0 to Parent.Count - 1 do
      if Parent.Items[I].Name = 'VisualRoot' then
      begin
        FVisRoot := Parent.Items[I];
        Break;
      end;

  K := 1 - Exp(-FSmoothFactor * SecondsPassed);

  Parent.Translation := Parent.Translation + (FTargetPos - Parent.Translation) * K;

  if FVisRoot <> nil then
    CurrRot := FVisRoot.Rotation.W
  else
    CurrRot := Parent.Rotation.W;
  Diff := FTargetRot - CurrRot;
  if Diff > Pi then Diff := Diff - 2 * Pi;
  if Diff < -Pi then Diff := Diff + 2 * Pi;
  if Abs(Diff) > 0.001 then
  begin
    if FVisRoot <> nil then
      FVisRoot.Rotation := Vector4(0, 1, 0, CurrRot + Diff * K)
    else
      Parent.Rotation := Vector4(0, 1, 0, CurrRot + Diff * K);
  end;
end;

end.
