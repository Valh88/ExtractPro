unit CharacterControllerBehavior;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  CastleVectors, CastleTransform, CastleCameras,
  CastleViewport, CastleUIControls, CastleKeysMouse, CastleApplicationProperties,
  FirstPersonCameraBehavior, TouchMoveControl,
  PlayerAnimationBehavior;

type
  TCharacterControllerBehavior = class(TCastleBehavior)
  private
    FViewport: TCastleViewport;
    FCamera: TCastleCamera;
    FMoveSpeed: Single;
    FJumpSpeed: Single;
    FSmoothStop: Single;
    FTouchMove: TVector2;
    FTouchMoveControl: TTouchMoveControl;
    FMoving: Boolean;
    FCanJump: Boolean;
    FFirstPersonCam: TFirstPersonCameraBehavior;
    FInputEnabled: Boolean;
    FRunning: Boolean;
    FMoveDir: TVector3;
    procedure EnsureTouchMoveControl;
    function GetContainer: TCastleContainer;
    function GetRigidBody: TCastleRigidBody;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    function ForwardDir: TVector3;
    function RightDir: TVector3;

    property Viewport: TCastleViewport read FViewport write FViewport;
    property Camera: TCastleCamera read FCamera write FCamera;
    property MoveSpeed: Single read FMoveSpeed write FMoveSpeed;
    property SmoothStop: Single read FSmoothStop write FSmoothStop;
    property JumpSpeed: Single read FJumpSpeed write FJumpSpeed;
    property TouchMove: TVector2 read FTouchMove write FTouchMove;
    property FirstPersonCam: TFirstPersonCameraBehavior read FFirstPersonCam write FFirstPersonCam;
    property InputEnabled: Boolean read FInputEnabled write FInputEnabled;
    property Moving: Boolean read FMoving;
    property Running: Boolean read FRunning;
    property MoveDir: TVector3 read FMoveDir;
  end;

implementation

uses
  Math;

constructor TCharacterControllerBehavior.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FViewport := nil;
  FCamera := nil;
  FTouchMoveControl := nil;
  FTouchMove := TVector2.Zero;
  FMoveSpeed := 6.0;
  FSmoothStop := 8.0;
  FJumpSpeed := 6.0;
  FInputEnabled := True;
  FRunning := False;
  FMoveDir := TVector3.Zero;
end;

procedure TCharacterControllerBehavior.EnsureTouchMoveControl;
var
  View: TCastleView;
begin
  if (FViewport = nil) or (FTouchMoveControl <> nil) or not ApplicationProperties.TouchDevice then Exit;
  if not (FViewport.Parent is TCastleView) then Exit;
  View := TCastleView(FViewport.Parent);
  FTouchMoveControl := TTouchMoveControl.Create(View);
  FTouchMoveControl.InvertVertical := true;
  FTouchMoveControl.Exists := true;
  View.InsertFront(FTouchMoveControl);
end;

function TCharacterControllerBehavior.GetContainer: TCastleContainer;
begin
  Result := nil;
  if FViewport <> nil then
    Result := FViewport.Container;
end;

function TCharacterControllerBehavior.GetRigidBody: TCastleRigidBody;
begin
  Result := nil;
  if Parent <> nil then
    Result := Parent.FindBehavior(TCastleRigidBody) as TCastleRigidBody;
end;

function TCharacterControllerBehavior.ForwardDir: TVector3;
var
  Angle: Single;
begin
  if FFirstPersonCam <> nil then
    Angle := FFirstPersonCam.TargetAngle
  else
    Angle := 0;
  Result := Vector3(Sin(Angle), 0, -Cos(Angle));
end;

function TCharacterControllerBehavior.RightDir: TVector3;
begin
  Result := TVector3.CrossProduct(ForwardDir, Vector3(0, 1, 0));
end;

procedure TCharacterControllerBehavior.Update(const SecondsPassed: Single;
  var RemoveMe: TRemoveType);
var
  Cont: TCastleContainer;
  RB: TCastleRigidBody;
  MoveDirLocal, Vel: TVector3;
  Speed: Single;
  AnimBeh: TPlayerAnimationBehavior;
begin
  inherited Update(SecondsPassed, RemoveMe);
  RemoveMe := rtNone;

  if Parent = nil then Exit;

  Cont := GetContainer;
  if Cont = nil then Exit;

  RB := GetRigidBody;
  if RB = nil then Exit;

  if not FInputEnabled then
  begin
    RB.LinearVelocity := TVector3.Zero;
    FMoving := False;
    Exit;
  end;

  EnsureTouchMoveControl;
  if FTouchMoveControl <> nil then
    FTouchMove := FTouchMoveControl.MoveVector
  else
    FTouchMove := TVector2.Zero;

  Speed := FMoveSpeed;

  MoveDirLocal := TVector3.Zero;
  FMoving := false;

  if FTouchMove.Length > 0.01 then
  begin
    MoveDirLocal := ForwardDir * FTouchMove.Y + RightDir * FTouchMove.X;
    FMoving := true;
  end;

  if not FMoving then
  begin
    if Cont.Pressed[keyW] or Cont.Pressed[keyArrowUp] then
    begin
      MoveDirLocal := MoveDirLocal + ForwardDir;
      FMoving := true;
    end;
    if Cont.Pressed[keyS] or Cont.Pressed[keyArrowDown] then
    begin
      MoveDirLocal := MoveDirLocal - ForwardDir;
      FMoving := true;
    end;
    if Cont.Pressed[keyD] or Cont.Pressed[keyArrowRight] then
    begin
      MoveDirLocal := MoveDirLocal + RightDir;
      FMoving := true;
    end;
    if Cont.Pressed[keyA] or Cont.Pressed[keyArrowLeft] then
    begin
      MoveDirLocal := MoveDirLocal - RightDir;
      FMoving := true;
    end;
  end;
  if Cont.Pressed[keyShift] then
    Speed := Speed * 2
  else
    Speed := FMoveSpeed;
  FRunning := Cont.Pressed[keyShift];
  FMoveDir := MoveDirLocal;
  Vel := RB.LinearVelocity;

  if FMoving then
  begin
    if not MoveDirLocal.IsPerfectlyZero then
      MoveDirLocal := MoveDirLocal.Normalize;
    Vel.X := MoveDirLocal.X * Speed;
    Vel.Z := MoveDirLocal.Z * Speed;
  end else
  begin
    Vel.X := Vel.X * 0.85;
    Vel.Z := Vel.Z * 0.85;
    if Abs(Vel.X) < 0.01 then Vel.X := 0;
    if Abs(Vel.Z) < 0.01 then Vel.Z := 0;
  end;

  FCanJump := Abs(Vel.Y) < 0.01;
  if FCanJump and Cont.Pressed[keySpace] then
  begin
    Vel.Y := FJumpSpeed;
    if Parent <> nil then
    begin
      AnimBeh := Parent.FindBehavior(TPlayerAnimationBehavior) as TPlayerAnimationBehavior;
      if AnimBeh <> nil then
        AnimBeh.RequestJump;
    end;
  end;

  RB.LinearVelocity := Vel;

  { Определяем состояние анимации локального (майн) игрока. }
  if Parent <> nil then
  begin
    AnimBeh := Parent.FindBehavior(TPlayerAnimationBehavior) as TPlayerAnimationBehavior;
    if AnimBeh <> nil then
    begin
      if not FMoving then
        AnimBeh.SetState(msIdle)
      else if FRunning then
        AnimBeh.SetState(msRunForward)
      else
        AnimBeh.SetState(msWalkForward);
      if FFirstPersonCam <> nil then
        AnimBeh.SetPitch(FFirstPersonCam.PitchAngle);
    end;
  end;
end;

end.
