unit PlayerInterpolationBehavior;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Math,
  CastleTransform, CastleVectors,
  CastleScene, CastleQuaternions,
  X3DNodes,
  BehaviorBase;

type
  TPlayerInterpolation = class(TBehaviorBase)
  private
    FTargetPos: TVector3;
    FTargetRot: Single;
    FTargetPitch: Single;
    FVisRoot: TCastleTransform;
    FHeadBone: TTransformNode;
    FHeadBaseRot: TVector4;
    FHeadSearched: Boolean;
    FPitch: Single;
    FSmoothFactor: Single;
    function FindHeadBone: TTransformNode;
    function HeadRotationForPitch(const APitch: Single): TVector4;
    procedure ApplyPitch(const APitch: Single);

  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTarget(const AX, AY, AZ, ARotY, APitch: Single);
    procedure SnapTo(const AX, AY, AZ, ARotY, APitch: Single);
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    property SmoothFactor: Single read FSmoothFactor write FSmoothFactor;
  end;

implementation

{ Центр модели подключённого игрока относительно root PlayerPrototype.
  Модель glb (меш Y от -125 до +125, RigModels translation Y=125, scale 0.0068):
  bbox Min.Y=-0.92, Max.Y=+0.78 -> центр = -0.07.
  root.Y = serverY - центр, чтобы центр модели совпадал с серверной позицией. }
const
  ModelCenterOffset: Single = 0.07;

{ Опускает визуальную модель (VisualRoot) внутри root, чтобы ноги модели
  стояли на земле, не сдвигая коллайдер (коллайдер привязан к root). }
const
  VisualRootYOffset: Single = -0.78;

{ TPlayerInterpolation }

constructor TPlayerInterpolation.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSmoothFactor := 20.0;
  FHeadBone := nil;
  FHeadSearched := False;
  FHeadBaseRot := TVector4.Zero;
  FPitch := 0;
end;

function TPlayerInterpolation.FindHeadBone: TTransformNode;
var
  I: Integer;
  Model: TCastleScene;
begin
  Result := FHeadBone;
  if FHeadSearched then Exit;
  FHeadSearched := True;
  if Parent = nil then Exit;
  if FVisRoot = nil then
    for I := 0 to Parent.Count - 1 do
      if Parent.Items[I].Name = 'VisualRoot' then
      begin
        FVisRoot := Parent.Items[I];
        Break;
      end;
  if FVisRoot <> nil then
  begin
    for I := 0 to FVisRoot.Count - 1 do
      if FVisRoot.Items[I] is TCastleScene then
      begin
        Model := TCastleScene(FVisRoot.Items[I]);
        if Model.RootNode <> nil then
        begin
          Result := Model.RootNode.FindNode(TTransformNode, 'headx',
            [fnNilOnMissing]) as TTransformNode;
          if Result <> nil then
            FHeadBaseRot := Result.Rotation;
        end;
        Break;
      end;
  end;
  FHeadBone := Result;
end;

function TPlayerInterpolation.HeadRotationForPitch(const APitch: Single): TVector4;
var
  QBase, QPitch: TQuaternion;
begin
  QBase := QuatFromAxisAngle(FHeadBaseRot, true);
  QPitch := QuatFromAxisAngle(TVector3.One[0], APitch, true);
  Result := (QBase * QPitch).ToAxisAngle;
end;

procedure TPlayerInterpolation.ApplyPitch(const APitch: Single);
begin
  if FHeadBone <> nil then
    FHeadBone.Rotation := HeadRotationForPitch(APitch);
end;

procedure TPlayerInterpolation.ApplyTarget(const AX, AY, AZ, ARotY, APitch: Single);
begin
  FTargetPos := Vector3(AX, AY, AZ);
  FTargetRot := ARotY;
  FTargetPitch := -APitch;
end;

procedure TPlayerInterpolation.SnapTo(const AX, AY, AZ, ARotY, APitch: Single);
var
  I: Integer;
begin
  FTargetPos := Vector3(AX, AY, AZ);
  FTargetRot := ARotY;
  FTargetPitch := -APitch;

  if Parent = nil then Exit;
  Parent.Translation := Vector3(AX, AY - ModelCenterOffset, AZ);

  if FVisRoot = nil then
    for I := 0 to Parent.Count - 1 do
      if Parent.Items[I].Name = 'VisualRoot' then
      begin
        FVisRoot := Parent.Items[I];
        Break;
      end;

  if FVisRoot <> nil then
  begin
    FVisRoot.Rotation := Vector4(0, 1, 0, FTargetRot);
    FVisRoot.Translation := Vector3(FVisRoot.Translation.X, VisualRootYOffset, FVisRoot.Translation.Z);
  end
  else
    Parent.Rotation := Vector4(0, 1, 0, FTargetRot);

  FindHeadBone;
  FPitch := FTargetPitch;
  ApplyPitch(FPitch);
end;

procedure TPlayerInterpolation.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
var
  K, Diff, CurrRot, DiffPitch: Single;
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

  Parent.Translation := Parent.Translation +
    (Vector3(FTargetPos.X, FTargetPos.Y - ModelCenterOffset, FTargetPos.Z) - Parent.Translation) * K;

  if FVisRoot <> nil then
    FVisRoot.Translation := Vector3(FVisRoot.Translation.X, VisualRootYOffset, FVisRoot.Translation.Z);

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

  FindHeadBone;
  DiffPitch := FTargetPitch - FPitch;
  if DiffPitch > Pi then DiffPitch := DiffPitch - 2 * Pi;
  if DiffPitch < -Pi then DiffPitch := DiffPitch + 2 * Pi;
  if Abs(DiffPitch) > 0.001 then
  begin
    FPitch := FPitch + DiffPitch * K;
    ApplyPitch(FPitch);
  end;
end;

end.
