{
  Поведение: камера от первого или третьего лица + движение WASD.

  Режимы (CameraMode):
    cmFirstPerson  — камера на уровне глаз, смотрит вперёд.
    cmThirdPerson  — камера сзади и выше, смотрит на игрока.

  Управление мышью:
    Горизонталь (влево/вправо) — поворачивает ВСЁ ТЕЛО вместе с камерой.
      Тело физически вращается через RigidBody.AngularVelocity.
    Вертикаль (вверх/вниз) — только камера наклоняется, тело остаётся прямым.

  Третье лицо — расположение камеры:
    CameraDistance — расстояние сзади игрока.
    CameraHeight   — высота над точкой FocusHeight.
    FocusHeight    — высота точки на теле, куда смотрит камера.
    Камера всегда смотрит на тело, двигается по сфере вокруг него.

  Движение WASD: RigidBody.LinearVelocity (как ctVelocity в CGE).

  Предусловия:
    - Камера дочерняя к игроку (Camera1.Parent = MainPlayer).
    - TCastleRigidBody с Dynamic=True, LockRotation=[0,2].
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
    { Первое лицо }
    FEyeHeight: Single;
    { Третье лицо }
    FCameraDistance: Single;  { расстояние сзади }
    FCameraHeight: Single;    { высота камеры над FocusHeight }
    FFocusHeight: Single;     { высота точки на теле, куда смотрит камера }
    { Внутренние углы }
    FAngleHorizontal: Single;
    FAngleVertical: Single;
    FSmoothedH: Single;
    FSmoothedV: Single;
    { Плавность позиции камеры (3rd person) }
    FSmoothedCamPos: TVector3;
    FSmoothedCamPosValid: Boolean;
    { Mouse }
    FSmoothedDelta: TVector2;
    { Режим MouseLook: дельта приходит из Motion через AddMouseLookDelta, мышь держится в центре контейнером. }
    FMouseLookMode: Boolean;
    FAccumulatedMouseDelta: TVector2;
    { true = курсор виден, камера не вращается от мыши; false = курсор скрыт, MouseLook (мышь в центре). }
    FCursorVisible: Boolean;

    function GetContainer: TCastleContainer;
    function GetRigidBody: TCastleRigidBody;
    { Горизонтальный вектор "вперёд" по FAngleHorizontal }
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
    { Добавить дельту мыши из Motion (вызывать из обработчика, когда используется MouseLookDelta контейнера). }
    procedure AddMouseLookDelta(const PixelDelta: TVector2);
    { true = управление по дельте из AddMouseLookDelta, мышь в центре; false = по позиции мыши. }
    property MouseLookMode: Boolean read FMouseLookMode write FMouseLookMode;
    { true = курсор виден, поведение не вращает камеру от мыши; false = курсор скрыт, полноценный MouseLook. }
    property CursorVisible: Boolean read FCursorVisible write SetCursorVisible;

    property Camera: TCastleCamera read FCamera write FCamera;
    property Viewport: TCastleViewport read FViewport write FViewport;
    { Режим камеры: первое или третье лицо. }
    property CameraMode: TCameraMode read FCameraMode write FCameraMode;
    property MouseSensitivity: Single read FMouseSensitivity write FMouseSensitivity;
    property InvertVerticalMouseLook: Boolean
      read FInvertVerticalMouseLook write FInvertVerticalMouseLook;
    { Инверсия вертикали в режиме третьего лица (независимо от InvertVerticalMouseLook). }
    property InvertVerticalThirdPerson: Boolean
      read FInvertVerticalThirdPerson write FInvertVerticalThirdPerson;
    property InvertHorizontalMouseLook: Boolean
      read FInvertHorizontalMouseLook write FInvertHorizontalMouseLook;
    { Сглаживание углов камеры. 0 = мгновенно. }
    property CameraSmoothFactor: Single
      read FCameraSmoothFactor write FCameraSmoothFactor;
    { Сглаживание дельты мыши. 0 = выкл. }
    property MouseSmoothFactor: Single
      read FMouseSmoothFactor write FMouseSmoothFactor;
    { Первое лицо: высота глаз над центром тела. }
    property EyeHeight: Single read FEyeHeight write FEyeHeight;
    { Третье лицо: расстояние камеры сзади игрока. }
    property CameraDistance: Single read FCameraDistance write FCameraDistance;
    { Третье лицо: высота камеры над точкой фокуса. }
    property CameraHeight: Single read FCameraHeight write FCameraHeight;
    { Третье лицо: высота точки на теле, на которую смотрит камера. }
    property FocusHeight: Single read FFocusHeight write FFocusHeight;
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
  FInvertVerticalThirdPerson := True;   { в 3rd person вверх мыши = камера вниз по умолчанию инвертирована }
  FInvertHorizontalMouseLook := False;
  FCameraSmoothFactor := 15;
  FMouseSmoothFactor := 0;
  FEyeHeight := 1.2;
  FCameraDistance := 4.0;
  FCameraHeight := 2.0;
  FFocusHeight := 1.0;
  FAngleHorizontal := 0;
  FAngleVertical := 0;
  FSmoothedH := 0;
  FSmoothedV := 0;
  FSmoothedCamPosValid := False;
  FSmoothedDelta := TVector2.Zero;
  FMouseLookMode := False;
  FAccumulatedMouseDelta := TVector2.Zero;
  FCursorVisible := False;
end;

procedure TFirstPersonCameraBehavior.SetCursorVisible(const Value: Boolean);
begin
  if FCursorVisible = Value then Exit;
  FCursorVisible := Value;
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
  Result := Vector3(Sin(FAngleHorizontal), 0, -Cos(FAngleHorizontal));
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
  FocusPos: TVector3;   { точка на теле, куда смотрит камера }
  CamOffset: TVector3;  { смещение камеры от FocusPos }
  CamPos: TVector3;
  CamDir, CamUp: TVector3;
  SmoothK: Single;
begin
  { Точка фокуса — центр тела + FocusHeight }
  FocusPos := Parent.WorldTranslation + Vector3(0, FFocusHeight, 0);

  { Смещение камеры: назад по горизонтальному углу + вверх.
    Вертикальный угол (FSmoothedV) наклоняет камеру вверх/вниз по сфере. }
  CamOffset.X := -SH * CP * FCameraDistance;
  CamOffset.Y :=  SP * FCameraDistance + FCameraHeight;
  CamOffset.Z :=  CH * CP * FCameraDistance;

  CamPos := FocusPos + CamOffset;

  { Плавное движение позиции камеры — убирает дёрганье }
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

  { Камера всегда смотрит на FocusPos }
  CamDir := (FocusPos - CamPos).Normalize;
  CamUp := Vector3(0, 1, 0);

  FCamera.SetWorldView(CamPos, CamDir, CamUp);
end;

procedure TFirstPersonCameraBehavior.Update(const SecondsPassed: Single;
  var RemoveMe: TRemoveType);
var
  Cont: TCastleContainer;
  RB: TCastleRigidBody;
  Delta: TVector2;
  CH, SH, CP, SP: Single;
  SmoothK: Single;
  AngleDelta: Single;
begin
  inherited Update(SecondsPassed, RemoveMe);
  RemoveMe := rtNone;

  if Parent = nil then Exit;
  if FCamera = nil then Exit;
  Cont := GetContainer;
  if Cont = nil then Exit;

  FMouseLookMode := not FCursorVisible;
  { Курсор: при скрытом — MouseLook (центр экрана), при видимом — не вращаем камеру от мыши. }
  if FCursorVisible then
    Cont.OverrideCursor := mcDefault
  else
  begin
    Cont.OverrideCursor := mcForceNone;
    Cont.MouseLookUpdate;
  end;

  { === Дельта мыши === }
  if FMouseLookMode then
  begin
    { Режим MouseLook: дельта накоплена из Motion (MouseLookDelta контейнера держит мышь в центре). }
    if (Cont.UnscaledWidth > 0) and (Cont.UnscaledHeight > 0) then
    begin
      Delta.X := FAccumulatedMouseDelta.X / Cont.UnscaledWidth;
      Delta.Y := FAccumulatedMouseDelta.Y / Cont.UnscaledHeight;
    end else
      Delta := TVector2.Zero;
    FAccumulatedMouseDelta := TVector2.Zero;
  end else
  begin
    { Курсор виден — не вращаем камеру от мыши. }
    Delta := TVector2.Zero;
  end;

  if FInvertHorizontalMouseLook then Delta.X := -Delta.X;
  if FInvertVerticalMouseLook   then Delta.Y := -Delta.Y;
  { Дополнительная инверсия вертикали для 3го лица }
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

  { Горизонталь — поворот всего тела }
  FAngleHorizontal := FAngleHorizontal - Delta.X * FMouseSensitivity;

  { Вертикаль — только наклон камеры }
  FAngleVertical := FAngleVertical + Delta.Y * FMouseSensitivity;
  case FCameraMode of
    cmFirstPerson: FAngleVertical := EnsureRange(FAngleVertical, -Pi * 0.45, Pi * 0.45);
    cmThirdPerson: FAngleVertical := EnsureRange(FAngleVertical, -Pi * 0.35, Pi * 0.35);
  end;

  { === Сглаживание углов === }
  if FCameraSmoothFactor > 0 then
  begin
    SmoothK := 1 - Exp(-FCameraSmoothFactor * SecondsPassed);
    FSmoothedH := FSmoothedH + (FAngleHorizontal - FSmoothedH) * SmoothK;
    FSmoothedV := FSmoothedV + (FAngleVertical   - FSmoothedV) * SmoothK;
  end else
  begin
    FSmoothedH := FAngleHorizontal;
    FSmoothedV := FAngleVertical;
  end;

  CH := Cos(FSmoothedH); SH := Sin(FSmoothedH);
  CP := Cos(FSmoothedV); SP := Sin(FSmoothedV);

  { === Позиция и ориентация камеры === }
  case FCameraMode of
    cmFirstPerson: ApplyFirstPersonCamera(CH, SH, CP, SP);
    cmThirdPerson: ApplyThirdPersonCamera(CH, SH, CP, SP, SecondsPassed);
  end;

  { Поворот тела физически: задаём AngularVelocity.Y, чтобы тело само поворачивалось к FSmoothedH (не перезаписываем Rotation каждый кадр). }
  AngleDelta := FSmoothedH - Parent.Rotation.W;
  while AngleDelta > Pi do AngleDelta := AngleDelta - 2 * Pi;
  while AngleDelta < -Pi do AngleDelta := AngleDelta + 2 * Pi;
  RB := GetRigidBody;
  if RB = nil then Exit;
  RB.AngularVelocity := Vector3(0, AngleDelta * 12, 0);
end;

end.
