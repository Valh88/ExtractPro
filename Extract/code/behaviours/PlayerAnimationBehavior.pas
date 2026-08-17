unit PlayerAnimationBehavior;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Math,
  CastleTransform, CastleVectors,
  CastleScene, CastleSceneCore, CastleQuaternions,
  X3DNodes,
  BehaviorBase;

type
  { Состояние движения игрока, по которому выбирается анимация. }
  TPlayerMoveState = (
    msIdle,
    msWalkForward,
    msRunForward,
    msWalkBack,
    msWalkLeft,
    msWalkRight
  );

  { Управляет анимациями модели игрока: движением (плавный cross-fade),
    pitch головы (поверх анимации) и заделом под прыжок.
    Общий для локального (майн) и подключённых игроков. }
  TPlayerAnimationBehavior = class(TCastleBehavior)
  private
    FModel: TCastleScene;
    FHeadBone: TTransformNode;
    FHeadBaseRot: TVector4;
    FHeadSearched: Boolean;
    FPitch: Single;
    FPitchEnabled: Boolean;
    FCurrentState: TPlayerMoveState;
    FTransitionDuration: Single;
    FJumpPending: Boolean;
    function FindHeadBone: TTransformNode;
    function HeadRotationForPitch(const APitch: Single): TVector4;
    procedure ApplyPitch(const APitch: Single);
    function AnimationNameForState(const AState: TPlayerMoveState): String;
    procedure ApplyState(const AState: TPlayerMoveState);
  public
    constructor Create(AOwner: TComponent; const AModel: TCastleScene); reintroduce;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    procedure SetState(const AState: TPlayerMoveState);
    procedure SetPitch(const APitch: Single);
    { Задел под прыжок: анимация Run Jump Over. Пока заглушка. }
    procedure RequestJump;
    property PitchEnabled: Boolean read FPitchEnabled write FPitchEnabled;
    property TransitionDuration: Single read FTransitionDuration write FTransitionDuration;
    property CurrentState: TPlayerMoveState read FCurrentState;
  end;

implementation

const
  { Имя анимации прыжка (задел). }
  JumpAnimationName = 'Run Jump Over';

function TPlayerAnimationBehavior.AnimationNameForState(const AState: TPlayerMoveState): String;
begin
  case AState of
    msWalkForward, msRunForward: Result := 'Running';
    msWalkBack: Result := 'Running Backward';
    msWalkLeft: Result := 'Left Strafe';
    msWalkRight: Result := 'Right Strafe';
  else
    Result := 'IdleCasual';
  end;
end;

constructor TPlayerAnimationBehavior.Create(AOwner: TComponent; const AModel: TCastleScene);
begin
  inherited Create(AOwner);
  FModel := AModel;
  FHeadBone := nil;
  FHeadBaseRot := TVector4.Zero;
  FHeadSearched := False;
  FPitch := 0;
  FPitchEnabled := False; { pitch головы выключен по умолчанию }
  FCurrentState := msIdle;
  FTransitionDuration := 0.25;
  FJumpPending := False;
end;

function TPlayerAnimationBehavior.FindHeadBone: TTransformNode;
begin
  Result := FHeadBone;
  if FHeadSearched then Exit;
  FHeadSearched := True;
  if FModel = nil then Exit;
  if FModel.RootNode <> nil then
  begin
    Result := FModel.RootNode.FindNode(TTransformNode, 'headx',
      [fnNilOnMissing]) as TTransformNode;
    if Result <> nil then
      FHeadBaseRot := Result.Rotation;
  end;
  FHeadBone := Result;
end;

function TPlayerAnimationBehavior.HeadRotationForPitch(const APitch: Single): TVector4;
var
  QBase, QPitch: TQuaternion;
begin
  QBase := QuatFromAxisAngle(FHeadBaseRot, true);
  QPitch := QuatFromAxisAngle(TVector3.One[0], APitch, true);
  Result := (QBase * QPitch).ToAxisAngle;
end;

procedure TPlayerAnimationBehavior.ApplyPitch(const APitch: Single);
begin
  if FHeadBone <> nil then
    FHeadBone.Rotation := HeadRotationForPitch(APitch);
end;

procedure TPlayerAnimationBehavior.ApplyState(const AState: TPlayerMoveState);
var
  P: TPlayAnimationParameters;
begin
  if FModel = nil then Exit;
  { Не перезапускаем, если анимация та же (walk/run -> "Running"). }
  if AnimationNameForState(AState) = AnimationNameForState(FCurrentState) then Exit;
  FCurrentState := AState;
  P := TPlayAnimationParameters.Create;
  try
    P.Name := AnimationNameForState(AState);
    P.Loop := True;
    P.TransitionDuration := FTransitionDuration;
    FModel.PlayAnimation(P);
  finally
    P.Free;
  end;
end;

procedure TPlayerAnimationBehavior.SetState(const AState: TPlayerMoveState);
begin
  ApplyState(AState);
end;

procedure TPlayerAnimationBehavior.SetPitch(const APitch: Single);
begin
  if not FPitchEnabled then
  begin
    FPitch := APitch;
    Exit;
  end;
  FPitch := APitch;
end;

procedure TPlayerAnimationBehavior.RequestJump;
begin
  FJumpPending := True;
end;

procedure TPlayerAnimationBehavior.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
begin
  inherited Update(SecondsPassed, RemoveMe);
  RemoveMe := rtNone;

  { Применяем pitch головы поверх анимации.
    SetPitch задаёт целевое значение; здесь оно пишется в кость каждый кадр. }
  FindHeadBone;
  if FPitchEnabled and (FHeadBone <> nil) then
    ApplyPitch(FPitch);

  { Задел под прыжок: воспроизвести одноразовую анимацию. }
  if FJumpPending then
  begin
    FJumpPending := False;
    if FModel <> nil then
      FModel.PlayAnimation(JumpAnimationName, False);
  end;
end;

end.
