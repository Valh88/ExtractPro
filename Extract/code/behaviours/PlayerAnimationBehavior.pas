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

  { Управляет анимациями модели игрока: движением (плавный cross-fade)
    и pitch головы (поверх анимации).
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
    FStateApplied: Boolean;
    FTransitionDuration: Single;
    FJumping: Boolean;
    FJumpTimer: Single;
    FStateBeforeJump: TPlayerMoveState;
    procedure EndJump;
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
    { Прыжок: проигрывает анимацию Jump (не разворачивает модель)
      один раз, затем возвращает анимацию движения. }
    procedure RequestJump;
    property PitchEnabled: Boolean read FPitchEnabled write FPitchEnabled;
    property TransitionDuration: Single read FTransitionDuration write FTransitionDuration;
    property CurrentState: TPlayerMoveState read FCurrentState;
    property Jumping: Boolean read FJumping;
  end;

implementation

function TPlayerAnimationBehavior.AnimationNameForState(const AState: TPlayerMoveState): String;
begin
  case AState of
    msWalkForward, msRunForward: Result := 'Running';
    msWalkBack: Result := 'Running Backward';
    msWalkLeft: Result := 'Left Strafe';
    msWalkRight: Result := 'Right Strafe';
  else
    Result := 'IdleLong';
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
  FStateApplied := False;
  FTransitionDuration := 0.25;
  FJumping := False;
  FJumpTimer := 0;
  FStateBeforeJump := msIdle;
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
  { Не перезапускаем, если анимация та же (walk/run -> "Running"),
    кроме первого раза (чтобы idle-анимация запустилась при создании). }
  if FStateApplied and (AnimationNameForState(AState) = AnimationNameForState(FCurrentState)) then Exit;
  FStateApplied := True;
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
  { Пока идёт прыжок — игнорируем смену состояния движения,
    чтобы анимация прыжка доиграла. }
  if FJumping then Exit;
  ApplyState(AState);
end;

procedure TPlayerAnimationBehavior.SetPitch(const APitch: Single);
begin
  FPitch := APitch;
end;

procedure TPlayerAnimationBehavior.EndJump;
begin
  FJumping := False;
  { Возвращаем анимацию, которая была до прыжка. }
  FStateApplied := False; { принудительно перезапускаем }
  ApplyState(FStateBeforeJump);
end;

procedure TPlayerAnimationBehavior.RequestJump;
var
  P: TPlayAnimationParameters;
begin
  if (FModel = nil) or FJumping then Exit;
  FJumping := True;
  FStateBeforeJump := FCurrentState; { запоминаем анимацию до прыжка }
  FJumpTimer := 0.88; { длительность анимации Jump }
  P := TPlayAnimationParameters.Create;
  try
    P.Name := 'Jump';
    P.Loop := False;
    P.TransitionDuration := FTransitionDuration;
    FModel.PlayAnimation(P);
  finally
    P.Free;
  end;
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

  { Прыжок закончился — возвращаем анимацию движения. }
  if FJumping then
  begin
    FJumpTimer := FJumpTimer - SecondsPassed;
    if FJumpTimer <= 0 then
      EndJump;
  end;
end;

end.
