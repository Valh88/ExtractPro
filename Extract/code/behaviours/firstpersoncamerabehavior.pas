{
  Поведение: камера от ��ервого или третьего лица + движение WASD.

  Режимы (CameraMode):
    cmFirstPerson  — камера на уровне глаз, смотрит вперёд.
    cmThirdPerson  — камера сзади и выше, смотрит на игрока.

  Управление мышью:
    Горизонталь / вертикаль — только камера (SetWorldView); корень игрока
      не поворачиваем — так нет конфликта с синхронизацией RigidBody и дёрганья.
    Движение WASD берёт направление из тех же углов (см. TargetAngle в CharacterController).

  Третье лицо — расположение камеры:
    CameraDistance — расстояние сзади игрока.
    CameraHeight   — высота над точкой FocusHeight.
    FocusHeight    — высота точки на теле, куда смотрит камера.
    Камера всегда смотрит на тело, двигается по сфере вокруг него.

  Движение WASD: RigidBody.LinearVelocity (как ctVelocity в CGE).

  Предусловия:
    - Камера дочерняя к игроку (Camera1.Parent = MainPlayer).
    - TCastleRigidBody с Dynamic=True, LockRotation по желанию (часто [0,1,2]).
}
unit FirstPersonCameraBehavior;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  CastleVectors, CastleTransform, CastleCameras,
  CastleViewport, CastleUIControls, CastleKeysMouse;

type
  TCameraMode = (cmFirstPerson, cmThirdPerson);

  TFirstPersonCameraBehavior = class(TCastleBehavior)
  private
    FCamera: TCastleCamera;
    FViewport: TCastleViewport;
    FCameraMode: TCameraMode;
    FMoveSpeed: Single;
    FMouseSensitivity: Single;
    FInvertVerticalMouseLook: Boolean;
    FInvertVerticalThirdPerson: Boolean;
    FInvertHorizontalMouseLook: Boolean;
    FCameraSmoothFactor: Single;
    FMouseSmoothFactor: Single;
    FEyeHeight: Single;
    FCameraDistance: Single;
    FCameraHeight: Single;
    FFocusHeight: Single;
    FAngleH: Single;
    FAngleV: Single;
    FSmoothedH: Single;
    FSmoothedV: Single;
    FSmoothedCamPos: TVector3;
    FSmoothedCamPosValid: Boolean;
    FSmoothedDelta: TVector2;
    FMouseLookMode: Boolean;
    FAccumulatedMouseDelta: TVector2;
    FCursorVisible: Boolean;
    FVisualRoot: TCastleTransform;
    FInputEnabled: Boolean;

    function GetContainer: TCastleContainer;
    function GetRigidBody: TCastleRigidBody;
    function ForwardDir: TVector3;
    function RightDir: TVector3;
    procedure ApplyFirstPersonCamera(const CH, SH, CP, SP: Single);
    procedure ApplyThirdPersonCamera(const CH, SH, CP, SP: Single;
      const SecondsPassed: Single);
  protected
    procedure SetCursorVisible(const Value: Boolean); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    procedure AddMouseLookDelta(const PixelDelta: TVector2);
    property MouseLookMode: Boolean read FMouseLookMode write FMouseLookMode;
    property CursorVisible: Boolean read FCursorVisible write SetCursorVisible;

    property Camera: TCastleCamera read FCamera write FCamera;
    property Viewport: TCastleViewport read FViewport write FViewport;
    property CameraMode: TCameraMode read FCameraMode write FCameraMode;
    property InputEnabled: Boolean read FInputEnabled write FInputEnabled;
    property MouseSensitivity: Single read FMouseSensitivity write FMouseSensitivity;
    property InvertVerticalMouseLook: Boolean
      read FInvertVerticalMouseLook write FInvertVerticalMouseLook;
    property InvertVerticalThirdPerson: Boolean
      read FInvertVerticalThirdPerson write FInvertVerticalThirdPerson;
    property InvertHorizontalMouseLook: Boolean
      read FInvertHorizontalMouseLook write FInvertHorizontalMouseLook;
    property CameraSmoothFactor: Single
      read FCameraSmoothFactor write FCameraSmoothFactor;
    property MouseSmoothFactor: Single
      read FMouseSmoothFactor write FMouseSmoothFactor;
    property EyeHeight: Single read FEyeHeight write FEyeHeight;
    property CameraDistance: Single read FCameraDistance write FCameraDistance;
    property CameraHeight: Single read FCameraHeight write FCameraHeight;
    property FocusHeight: Single read FFocusHeight write FFocusHeight;
    property HorizontalAngle: Single read FAngleH;
    property TargetAngle: Single read FSmoothedH;
    property VisualRoot: TCastleTransform read FVisualRoot write FVisualRoot;
  end;

implementation

uses
  Math;

constructor TFirstPersonCameraBehavior.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCamera := nil;
  FViewport := nil;
  FCameraMode := cmFirstPerson;
  FMoveSpeed := 5.0;
  FMouseSensitivity := 2.0;
  FInvertVerticalMouseLook := False;
  FInvertVerticalThirdPerson := True;
  FInvertHorizontalMouseLook := False;
  FCameraSmoothFactor := 15;
  FMouseSmoothFactor := 0;
  FEyeHeight := 1.2;
  FCameraDistance := 4.0;
  FCameraHeight := 2.0;
  FFocusHeight := 1.0;
  FAngleH := 0;
  FAngleV := 0;
  FSmoothedH := 0;
  FSmoothedV := 0;
  FSmoothedCamPosValid := False;
  FSmoothedDelta := TVector2.Zero;
  FMouseLookMode := False;
  FAccumulatedMouseDelta := TVector2.Zero;
  FCursorVisible := False;
  FInputEnabled := True;
end;

procedure TFirstPersonCameraBehavior.SetCursorVisible(const Value: Boolean);
begin
  if FCursorVisible = Value then Exit;
  FCursorVisible := Value;
  FAccumulatedMouseDelta := TVector2.Zero;
  FSmoothedDelta := TVector2.Zero;
  if not Value and (GetContainer <> nil) then
    GetContainer.MouseLookPress;
end;

procedure TFirstPersonCameraBehavior.AddMouseLookDelta(const PixelDelta: TVector2);
begin
  FAccumulatedMouseDelta := FAccumulatedMouseDelta + PixelDelta;
end;

function TFirstPersonCameraBehavior.GetContainer: TCastleContainer;
begin
  Result := nil;
  if FViewport <> nil then
    Result := FViewport.Container;
end;

function TFirstPersonCameraBehavior.GetRigidBody: TCastleRigidBody;
begin
  Result := nil;
  if Parent <> nil then
    Result := Parent.FindBehavior(TCastleRigidBody) as TCastleRigidBody;
end;

function TFirstPersonCameraBehavior.ForwardDir: TVector3;
begin
  Result := Vector3(Sin(FAngleH), 0, -Cos(FAngleH));
end;

function TFirstPersonCameraBehavior.RightDir: TVector3;
begin
  Result := TVector3.CrossProduct(ForwardDir, Vector3(0, 1, 0));
end;

procedure TFirstPersonCameraBehavior.ApplyFirstPersonCamera(
  const CH, SH, CP, SP: Single);
var
  CamDir, CamUp: TVector3;
  CamPos: TVector3;
begin
  CamDir.X :=  SH * CP;
  CamDir.Y :=  SP;
  CamDir.Z := -CH * CP;
  CamDir := CamDir.Normalize;
  CamUp := Vector3(0, 1, 0);
  CamPos := Parent.WorldTranslation + Vector3(0, FEyeHeight, 0);
  FCamera.SetWorldView(CamPos, CamDir, CamUp);
end;

procedure TFirstPersonCameraBehavior.ApplyThirdPersonCamera(
  const CH, SH, CP, SP: Single; const SecondsPassed: Single);
var
  FocusPos: TVector3;
  CamOffset: TVector3;
  CamPos: TVector3;
  CamDir, CamUp: TVector3;
  SmoothK: Single;
begin
  FocusPos := Parent.WorldTranslation + Vector3(0, FFocusHeight, 0);
  CamOffset.X := -SH * CP * FCameraDistance;
  CamOffset.Y :=  SP * FCameraDistance + FCameraHeight;
  CamOffset.Z :=  CH * CP * FCameraDistance;
  CamPos := FocusPos + CamOffset;
  if FCameraSmoothFactor > 0 then
  begin
    if not FSmoothedCamPosValid then
    begin
      FSmoothedCamPos := CamPos;
      FSmoothedCamPosValid := True;
    end else
    begin
      SmoothK := 1 - Exp(-FCameraSmoothFactor * SecondsPassed);
      FSmoothedCamPos := FSmoothedCamPos + (CamPos - FSmoothedCamPos) * SmoothK;
    end;
    CamPos := FSmoothedCamPos;
  end;
  CamDir := (FocusPos - CamPos).Normalize;
  CamUp := Vector3(0, 1, 0);
  FCamera.SetWorldView(CamPos, CamDir, CamUp);
end;

procedure TFirstPersonCameraBehavior.Update(const SecondsPassed: Single;
  var RemoveMe: TRemoveType);
var
  Cont: TCastleContainer;
  Delta: TVector2;
  RB: TCastleRigidBody;
  CH, SH, CP, SP: Single;
  SmoothK: Single;
begin
  inherited Update(SecondsPassed, RemoveMe);
  RemoveMe := rtNone;

  if not FInputEnabled then Exit;

  if Parent = nil then Exit;
  if FCamera = nil then Exit;
  Cont := GetContainer;
  if Cont = nil then Exit;

  FMouseLookMode := not FCursorVisible;
  if FCursorVisible then
    Cont.OverrideCursor := mcDefault
  else
  begin
    Cont.OverrideCursor := mcForceNone;
    Cont.MouseLookUpdate;
  end;

  if FMouseLookMode then
  begin
    if (Cont.UnscaledWidth > 0) and (Cont.UnscaledHeight > 0) then
    begin
      Delta.X := FAccumulatedMouseDelta.X / Cont.UnscaledWidth;
      Delta.Y := FAccumulatedMouseDelta.Y / Cont.UnscaledHeight;
    end else
      Delta := TVector2.Zero;
    if (Abs(Delta.X) > 0.0001) or (Abs(Delta.Y) > 0.0001) then
      FAccumulatedMouseDelta := TVector2.Zero;
  end else
    Delta := TVector2.Zero;

  if FInvertHorizontalMouseLook then Delta.X := -Delta.X;
  if FInvertVerticalMouseLook   then Delta.Y := -Delta.Y;
  if (FCameraMode = cmThirdPerson) and FInvertVerticalThirdPerson then
    Delta.Y := -Delta.Y;

  if FMouseSmoothFactor > 0 then
  begin
    SmoothK := 1 - Exp(-FMouseSmoothFactor * SecondsPassed);
    FSmoothedDelta.X := FSmoothedDelta.X + (Delta.X - FSmoothedDelta.X) * SmoothK;
    FSmoothedDelta.Y := FSmoothedDelta.Y + (Delta.Y - FSmoothedDelta.Y) * SmoothK;
    FSmoothedDelta.X := FSmoothedDelta.X * SmoothK;
    FSmoothedDelta.Y := FSmoothedDelta.Y * SmoothK;
    Delta := FSmoothedDelta;
  end;

  FAngleH := FAngleH + Delta.X * FMouseSensitivity;
  FAngleV := FAngleV + Delta.Y * FMouseSensitivity;
  case FCameraMode of
    cmFirstPerson: FAngleV := EnsureRange(FAngleV, -Pi * 0.45, Pi * 0.45);
    cmThirdPerson: FAngleV := EnsureRange(FAngleV, -Pi * 0.35, Pi * 0.35);
  end;

  if FCameraSmoothFactor > 0 then
  begin
    SmoothK := 1 - Exp(-FCameraSmoothFactor * SecondsPassed);
    FSmoothedH := FSmoothedH + (FAngleH - FSmoothedH) * SmoothK;
    FSmoothedV := FSmoothedV + (FAngleV - FSmoothedV) * SmoothK;
  end else
  begin
    FSmoothedH := FAngleH;
    FSmoothedV := FAngleV;
  end;

  if FVisualRoot <> nil then
    FVisualRoot.Rotation := Vector4(0, 1, 0, -FSmoothedH);

  CH := Cos(FSmoothedH); SH := Sin(FSmoothedH);
  CP := Cos(FSmoothedV); SP := Sin(FSmoothedV);

  case FCameraMode of
    cmFirstPerson: ApplyFirstPersonCamera(CH, SH, CP, SP);
    cmThirdPerson: ApplyThirdPersonCamera(CH, SH, CP, SP, SecondsPassed);
  end;
end;

end.
