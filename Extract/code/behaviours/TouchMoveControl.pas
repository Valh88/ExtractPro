{
  Сенсорный джойстик для движения: левая зона экрана, вывод MoveVector (X = вправо, Y = вперёд), -1..1.
  Используется CharacterControllerBehavior при ApplicationProperties.TouchDevice.
}
unit TouchMoveControl;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse, CastleRectangles,
  CastleApplicationProperties;

type
  TTouchMoveControl = class(TCastleUserInterface)
  private
    FMoveVector: TVector2;
    FStartPos: TVector2;
    FDragging: Integer;
    FMaxRadius: Single;
    FLeftZoneFraction: Single;
    FBottomZoneFraction: Single;
    FInvertVertical: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    function Press(const Event: TInputPressRelease): Boolean; override;
    function Release(const Event: TInputPressRelease): Boolean; override;
    function Motion(const Event: TInputMotion): Boolean; override;
    procedure Render; override;
    property MoveVector: TVector2 read FMoveVector write FMoveVector;
    { Доля ширины экрана (0..1) для зоны касания слева. По умолчанию 0.35. Увеличьте (например 0.5), чтобы зона Touch была шире. }
    property LeftZoneFraction: Single read FLeftZoneFraction write FLeftZoneFraction;
    { Доля высоты экрана (0..1) для зоны касания снизу: касания принимаются только при Y <= Height * BottomZoneFraction. По умолчанию 1.0 (вся высота). Уменьшите (например 0.7), чтобы ограничить зону снизу и задать максимальный верх для касания. }
    property BottomZoneFraction: Single read FBottomZoneFraction write FBottomZoneFraction;
    { Радиус джойстика в пикселях: ход стика и размер отрисовки. По умолчанию 80. Увеличьте (например 120–150) для более крупного джойстика. }
    property MaxRadius: Single read FMaxRadius write FMaxRadius;
    { Инверсия верха и низа: true = вверх по экрану даёт "назад", вниз — "вперёд". По умолчанию false. }
    property InvertVertical: Boolean read FInvertVertical write FInvertVertical;
  end;

implementation

uses
  Math;

constructor TTouchMoveControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMoveVector := TVector2.Zero;
  FDragging := -1;
  FMaxRadius := 80;
  FLeftZoneFraction := 0.35;
  FBottomZoneFraction := 0.7;
  FInvertVertical := false;
  FullSize := true;
end;

function TTouchMoveControl.Press(const Event: TInputPressRelease): Boolean;
var
  W, H: Single;
begin
  Result := inherited Press(Event);
  if Result then Exit;
  { На сенсорных устройствах касание приходит как itMouseButton; не отсекать его. На десктопе — не перехватывать мышь. }
  if not ApplicationProperties.TouchDevice and Event.IsMouseButton(buttonLeft) then Exit;
  if FDragging >= 0 then Exit;
  if Container = nil then Exit;
  W := Container.UnscaledWidth;
  H := Container.UnscaledHeight;
  if (W <= 0) or (H <= 0) then Exit;
  if Event.Position.X > W * FLeftZoneFraction then Exit;
  if Event.Position.Y > H * FBottomZoneFraction then Exit;
  FDragging := Event.FingerIndex;
  FStartPos := Event.Position;
  FMoveVector := TVector2.Zero;
  Result := true;
end;

function TTouchMoveControl.Release(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited Release(Event);
  if Event.FingerIndex = FDragging then
  begin
    FDragging := -1;
    FMoveVector := TVector2.Zero;
    VisibleChange([chRender]);
    Result := true;
  end;
end;

function TTouchMoveControl.Motion(const Event: TInputMotion): Boolean;
var
  Offset: TVector2;
  Len: Single;
begin
  Result := inherited Motion(Event);
  if not Result and (Event.FingerIndex = FDragging) then
  begin
    Offset := Event.Position - FStartPos;
    Len := Offset.Length;
    if Len > 0.01 then
    begin
      if Len > FMaxRadius then
        Offset := Offset * (FMaxRadius / Len);
      if FInvertVertical then
        FMoveVector := Vector2(Offset.X / FMaxRadius, Offset.Y / FMaxRadius)
      else
        FMoveVector := Vector2(Offset.X / FMaxRadius, -Offset.Y / FMaxRadius);
    end else
      FMoveVector := TVector2.Zero;
    VisibleChange([chRender]);
    Result := true;
  end;
end;

procedure TTouchMoveControl.Render;
var
  R: TFloatRectangle;
  StickCenter, Thumb: TVector2;
  OuterRect, InnerRect: TFloatRectangle;
  Scale: Single;
begin
  if FDragging < 0 then Exit;
  R := RenderRect;
  Scale := UIScale;
  StickCenter := Vector2(R.Left + R.Width * FLeftZoneFraction * 0.5, R.Bottom + R.Height * 0.2);
  OuterRect := FloatRectangle(
    StickCenter.X - Theme.ImagesPersistent[tiTouchCtlOuter].Width * Scale / 2,
    StickCenter.Y - Theme.ImagesPersistent[tiTouchCtlOuter].Height * Scale / 2,
    Theme.ImagesPersistent[tiTouchCtlOuter].Width * Scale,
    Theme.ImagesPersistent[tiTouchCtlOuter].Height * Scale);
  Theme.Draw(OuterRect, tiTouchCtlOuter, Scale);
  Thumb := StickCenter + FMoveVector * FMaxRadius * Scale;
  InnerRect := FloatRectangle(
    Thumb.X - Theme.ImagesPersistent[tiTouchCtlInner].Width * Scale / 2,
    Thumb.Y - Theme.ImagesPersistent[tiTouchCtlInner].Height * Scale / 2,
    Theme.ImagesPersistent[tiTouchCtlInner].Width * Scale,
    Theme.ImagesPersistent[tiTouchCtlInner].Height * Scale);
  Theme.Draw(InnerRect, tiTouchCtlInner, Scale);
end;

end.
