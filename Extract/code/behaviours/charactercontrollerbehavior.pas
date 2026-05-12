{
  Поведение: универсальный контроллер персонажа.

  - Движение WASD (или стрелки) по плоскости XZ.
  - На сенсорных устройствах автоматически создаётся TTouchMoveControl (джойстик слева) и его вектор используется для движения.
  - Прыжок по пробелу.

  Логика движения вынесена из FirstPersonCameraBehavior, чтобы её можно было
  переиспользовать с разными камерами.

  Предусловия:
    - Поведение добавлено к TCastleTransform с TCastleRigidBody (Dynamic = True).
    - Гравитация включена у rigid body.
}
unit CharacterControllerBehavior;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  CastleVectors, CastleTransform, CastleCameras,
  CastleViewport, CastleUIControls, CastleKeysMouse, CastleApplicationProperties,
  TouchMoveControl;

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
    procedure EnsureTouchMoveControl;
    function GetContainer: TCastleContainer;
    function GetRigidBody: TCastleRigidBody;
    function ForwardDir: TVector3;
    function RightDir: TVector3;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;

    { Вьюпорт, из которого берётся контейнер ввода. На сенсорных устройствах при установленном Viewport создаётся джойстик. }
    property Viewport: TCastleViewport read FViewport write FViewport;
    { Камера, по направлению взгляда которой считается "вперёд" для WASD. Если nil — используется ориентация тела (Parent.Direction). }
    property Camera: TCastleCamera read FCamera write FCamera;
    { Максимальная скорость бега по земле. }
    property MoveSpeed: Single read FMoveSpeed write FMoveSpeed;
    property SmoothStop: Single read FSmoothStop write FSmoothStop;
    { Начальная вертикальная скорость прыжка. }
    property JumpSpeed: Single read FJumpSpeed write FJumpSpeed;
    { Вектор движения от сенсорного джойстика (если используется). Можно задавать извне для кастомной логики. }
    property TouchMove: TVector2 read FTouchMove write FTouchMove;
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
  D: TVector3;
begin
  if (FCamera <> nil) and FCamera.HasWorldTransform then
    D := FCamera.WorldDirection
  else if (Parent <> nil) and Parent.HasWorldTransform then
    D := Parent.Direction
  else
    D := Vector3(0, 0, -1);

  D.Y := 0;
  if D.IsPerfectlyZero then
    Result := Vector3(0, 0, -1)
  else
    Result := D.Normalize;
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
  MoveDir, Vel: TVector3;
  Speed, DeltaSpeed, VLength: Single;
begin
  inherited Update(SecondsPassed, RemoveMe);
  RemoveMe := rtNone;

  if Parent = nil then Exit;

  Cont := GetContainer;
  if Cont = nil then Exit;

  RB := GetRigidBody;
  if RB = nil then Exit;

  EnsureTouchMoveControl;
  if FTouchMoveControl <> nil then
    FTouchMove := FTouchMoveControl.MoveVector
  else
    FTouchMove := TVector2.Zero;

  Speed := FMoveSpeed;
  DeltaSpeed := Speed * 3 * SecondsPassed;

  MoveDir := TVector3.Zero;
  FMoving := false;

  { Сенсорный джойстик: при ненулевом векторе используем его (Y = вперёд, X = вправо). }
  if FTouchMove.Length > 0.01 then
  begin
    MoveDir := ForwardDir * FTouchMove.Y + RightDir * FTouchMove.X;
    FMoving := true;
  end;

  if not FMoving then
  begin
    if Cont.Pressed[keyW] or Cont.Pressed[keyArrowUp] then
    begin
      MoveDir := MoveDir + ForwardDir;
      FMoving := true;
    end;
    if Cont.Pressed[keyS] or Cont.Pressed[keyArrowDown] then
    begin
      MoveDir := MoveDir - ForwardDir;
      FMoving := true;
    end;
    if Cont.Pressed[keyD] or Cont.Pressed[keyArrowRight] then
    begin
      MoveDir := MoveDir + RightDir;
      FMoving := true;
    end;
    if Cont.Pressed[keyA] or Cont.Pressed[keyArrowLeft] then
    begin
      MoveDir := MoveDir - RightDir;
      FMoving := true;
    end;
  end;
  if Cont.Pressed[keyShift] then
  begin
    Speed := Speed * 2;
  end else
  begin
    Speed := FMoveSpeed;
  end;
  Vel := RB.LinearVelocity;

  if FMoving then
  begin
    if not MoveDir.IsPerfectlyZero then
      MoveDir := MoveDir.Normalize;
    VLength := Vector2(Vel.X, Vel.Z).Length + DeltaSpeed;
    if VLength > Speed then VLength := Speed;
    Vel.X := MoveDir.X * VLength;
    Vel.Z := MoveDir.Z * VLength;
  end else
  begin
    Vel.X := Vel.X * (1 - FSmoothStop * SecondsPassed);
    Vel.Z := Vel.Z * (1 - FSmoothStop * SecondsPassed);
  end;

  { Прыжок: простая проверка "практически на земле" по вертикальной скорости. }
  FCanJump := Abs(Vel.Y) < 0.01;
  if FCanJump and Cont.Pressed[keySpace] then
    Vel.Y := FJumpSpeed;

  RB.LinearVelocity := Vel;
end;

end.

