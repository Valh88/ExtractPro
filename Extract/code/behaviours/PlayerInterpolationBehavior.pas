unit PlayerInterpolationBehavior;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Math,
  CastleTransform, CastleVectors,
  BehaviorBase,
  PlayerAnimationBehavior;

type
  TPlayerInterpolation = class(TBehaviorBase)
  private
    FTargetPos: TVector3;
    FTargetRot: Single;
    FVisRoot: TCastleTransform;
    FSmoothFactor: Single;
    FLastPos: TVector3;
    FLastTime: Single;
    FAnim: TPlayerAnimationBehavior;
    FLastState: TPlayerMoveState;
    function FindAnimationBehavior: TPlayerAnimationBehavior;
    function ComputeState(const MoveX, MoveZ: Single): TPlayerMoveState;
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

{ Пороги скорости (единицы/сек) для определения состояния анимации,
  с гистерезисом, чтобы избежать дёрганья idle <-> движение. }
const
  SpeedMoveOn = 0.4;   // скорость входа в движение
  SpeedMoveOff = 0.15; // скорость выхода в idle
  SpeedRunOn = 4.0;    // вход в бег

{ TPlayerInterpolation }

constructor TPlayerInterpolation.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSmoothFactor := 20.0;
  FLastPos := TVector3.Zero;
  FLastTime := 0;
  FAnim := nil;
  FLastState := msIdle;
end;

function TPlayerInterpolation.FindAnimationBehavior: TPlayerAnimationBehavior;
begin
  if FAnim = nil then
    FAnim := Parent.FindBehavior(TPlayerAnimationBehavior) as TPlayerAnimationBehavior;
  Result := FAnim;
end;

function TPlayerInterpolation.ComputeState(const MoveX, MoveZ: Single): TPlayerMoveState;
var
  MoveWorld, MoveLocal: TVector3;
  MoveLen, Dot: Single;
begin
  MoveWorld := Vector3(MoveX, 0, MoveZ);
  MoveLen := MoveWorld.Length;
  if MoveLen < SpeedMoveOn then
    Exit(msIdle);

  { Гистерезис idle <-> движение }
  if (FLastState <> msIdle) and (MoveLen < SpeedMoveOff) then
    Exit(msIdle);

  { Переводим мировой вектор движения в локальные координаты модели
    (учитывает yaw VisualRoot и статический поворот Model). }
  if FVisRoot <> nil then
    MoveLocal := FVisRoot.WorldToLocalDirection(MoveWorld)
  else
    MoveLocal := MoveWorld;

  { Локальный forward модели (из-за Ry(-90) поворота) = -X.
    Dot = MoveLocal . (-1,0,0) = -MoveLocal.X }
  Dot := -MoveLocal.X / Max(MoveLen, 0.001);

  if MoveLen >= SpeedRunOn then
    Result := msRunForward
  else
    Result := msWalkForward;

  if Dot < -0.5 then
    Result := msWalkBack
  else if (Dot >= -0.5) and (Dot <= 0.5) then
  begin
    { стрейф: локальный Z определяет влево/вправо. }
    if MoveLocal.Z < 0 then
      Result := msWalkRight
    else
      Result := msWalkLeft;
  end;
end;

procedure TPlayerInterpolation.ApplyTarget(const AX, AY, AZ, ARotY, APitch: Single);
begin
  FTargetPos := Vector3(AX, AY, AZ);
  FTargetRot := ARotY;
  FAnim := FindAnimationBehavior;
  if FAnim <> nil then
    FAnim.SetPitch(-APitch);
end;

procedure TPlayerInterpolation.SnapTo(const AX, AY, AZ, ARotY, APitch: Single);
var
  I: Integer;
begin
  FTargetPos := Vector3(AX, AY, AZ);
  FTargetRot := ARotY;

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

  FAnim := FindAnimationBehavior;
  if FAnim <> nil then
    FAnim.SetPitch(-APitch);
end;

procedure TPlayerInterpolation.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
var
  K, Diff, CurrRot: Single;
  I: Integer;
  MoveX, MoveZ: Single;
  DT: Single;
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

  { Вычисляем скорость движения по дельте позиции и определяем состояние анимации. }
  DT := FLastTime;
  FLastTime := SecondsPassed;
  MoveX := Parent.Translation.X - FLastPos.X;
  MoveZ := Parent.Translation.Z - FLastPos.Z;
  FLastPos := Parent.Translation;

  FAnim := FindAnimationBehavior;
  if FAnim <> nil then
    if DT > 0 then
    begin
      FLastState := ComputeState(MoveX / DT, MoveZ / DT);
      FAnim.SetState(FLastState);
    end;
end;

end.
