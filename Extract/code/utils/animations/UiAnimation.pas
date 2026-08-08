unit UiAnimation;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, CastleUIControls, CastleControls, CastleVectors, CastleColors, Math;

type
  TBaseAnimation = class
  private
    FDuration: Single;
    FProgress: Single;
    FOnComplete: TNotifyEvent;
  protected
    procedure DoAnimate(const Progress: Single); virtual; abstract;
  public
    constructor Create(const ADuration: Single);
    procedure Update(const SecondsPassed: Single); virtual;
    procedure Start;
    procedure Stop; virtual;
    function IsComplete: Boolean;
    property Duration: Single read FDuration write FDuration;
    property OnComplete: TNotifyEvent read FOnComplete write FOnComplete;
  end;

  TFadeAnimation = class(TBaseAnimation)
  private
    FOverlay: TCastleRectangleControl;
    FFromAlpha: Single;
    FToAlpha: Single;
  protected
    procedure DoAnimate(const Progress: Single); override;
  public
    constructor Create(AOverlay: TCastleRectangleControl; const ADuration: Single;
      const AFromAlpha, AToAlpha: Single);
  end;

  TColorAnimation = class(TBaseAnimation)
  private
    FLabel: TCastleLabel;
    FFromColor, FToColor: TVector4;
  protected
    procedure DoAnimate(const Progress: Single); override;
  public
    constructor Create(ALabel: TCastleLabel; const ADuration: Single;
      const AFromColor, AToColor: TVector4);
  end;

  TWidthAnimation = class(TBaseAnimation)
  private
    FControl: TCastleUserInterface;
    FFromWidth, FToWidth: Single;
  protected
    procedure DoAnimate(const Progress: Single); override;
  public
    constructor Create(AControl: TCastleUserInterface; const ADuration: Single;
      const AFromWidth, AToWidth: Single);
  end;

  TWobbleAnimation = class(TBaseAnimation)
  private
    FControl: TCastleUserInterface;
    FAmplitude: Single;
    FOriginX: Single;
  protected
    procedure DoAnimate(const Progress: Single); override;
  public
    constructor Create(AControl: TCastleUserInterface; const ADuration: Single;
      const AAmplitude: Single);
    procedure Stop; override;
  end;

  TScaleAnimation = class(TBaseAnimation)
  private
    FLbl: TCastleLabel;
    FFromScale, FToScale: Single;
  protected
    procedure DoAnimate(const Progress: Single); override;
  public
    constructor Create(ALbl: TCastleLabel; const ADuration: Single;
      const AFromScale, AToScale: Single);
    procedure Stop; override;
  end;

  { Анимация цифры обратного отсчёта: рост из точки с лёгким отскоком,
    удержание и сжатие обратно в точку. Длительность = 1 сек (тик отсчёта). }
  TCountdownPulseAnimation = class(TBaseAnimation)
  private
    FLbl: TCastleLabel;
    FGrowFraction: Single;
    FShrinkFraction: Single;
  protected
    procedure DoAnimate(const Progress: Single); override;
  public
    constructor Create(ALbl: TCastleLabel; const ADuration: Single);
    procedure Stop; override;
  end;

  TDotsAnimation = class(TBaseAnimation)
  private
    FLabel: TCastleLabel;
    FBaseText: string;
    FInterval: Single;
    FElapsed: Single;
    FDotCount: Integer;
  protected
    procedure DoAnimate(const Progress: Single); override;
  public
    constructor Create(ALabel: TCastleLabel; const ABaseText: string;
      const AInterval: Single);
    procedure Update(const SecondsPassed: Single); override;
    procedure Stop; override;
    procedure Reset(ALabel: TCastleLabel; const ABaseText: String);
  end;

  TDesignFadeAnimation = class(TBaseAnimation)
  private
    type
      TChildColorInfo = record
        Control: TCastleUserInterface;
        OriginalColor: TCastleColor;
      end;
    var
      FDesign: TCastleDesign;
      FFromAlpha, FToAlpha: Single;
      FChildColors: array of TChildColorInfo;
      FChildCount: Integer;
  protected
    procedure DoAnimate(const Progress: Single); override;
  public
    constructor Create(ADesign: TCastleDesign; const ADuration: Single;
      const AFromAlpha, AToAlpha: Single);
  end;

implementation

uses CastleUtils;

{ TBaseAnimation }

constructor TBaseAnimation.Create(const ADuration: Single);
begin
  inherited Create;
  FDuration := ADuration;
  FProgress := 0;
  FOnComplete := nil;
end;

procedure TBaseAnimation.Start;
begin
  FProgress := 0;
end;

procedure TBaseAnimation.Stop;
begin
  FProgress := 1;
end;

function TBaseAnimation.IsComplete: Boolean;
begin
  Result := FProgress >= 1;
end;

procedure TBaseAnimation.Update(const SecondsPassed: Single);
begin
  if IsComplete then Exit;
  FProgress := FProgress + SecondsPassed / FDuration;
  if FProgress >= 1 then
  begin
    DoAnimate(1);
    if Assigned(FOnComplete) then
      FOnComplete(Self);
  end
  else
    DoAnimate(FProgress);
end;

{ TFadeAnimation }

constructor TFadeAnimation.Create(AOverlay: TCastleRectangleControl;
  const ADuration: Single; const AFromAlpha, AToAlpha: Single);
begin
  inherited Create(ADuration);
  FOverlay := AOverlay;
  FFromAlpha := AFromAlpha;
  FToAlpha := AToAlpha;
end;

procedure TFadeAnimation.DoAnimate(const Progress: Single);
var
  Alpha: Single;
begin
  Alpha := FFromAlpha + (FToAlpha - FFromAlpha) * Progress;
  FOverlay.Color := Vector4(FOverlay.Color.X, FOverlay.Color.Y,
    FOverlay.Color.Z, Alpha);
end;

{ TColorAnimation }

constructor TColorAnimation.Create(ALabel: TCastleLabel;
  const ADuration: Single; const AFromColor, AToColor: TVector4);
begin
  inherited Create(ADuration);
  FLabel := ALabel;
  FFromColor := AFromColor;
  FToColor := AToColor;
end;

procedure TColorAnimation.DoAnimate(const Progress: Single);
begin
  FLabel.Color := Vector4(
    FFromColor.X + (FToColor.X - FFromColor.X) * Progress,
    FFromColor.Y + (FToColor.Y - FFromColor.Y) * Progress,
    FFromColor.Z + (FToColor.Z - FFromColor.Z) * Progress,
    FFromColor.W + (FToColor.W - FFromColor.W) * Progress
  );
end;

{ TWidthAnimation }

constructor TWidthAnimation.Create(AControl: TCastleUserInterface;
  const ADuration: Single; const AFromWidth, AToWidth: Single);
begin
  inherited Create(ADuration);
  FControl := AControl;
  FFromWidth := AFromWidth;
  FToWidth := AToWidth;
end;

procedure TWidthAnimation.DoAnimate(const Progress: Single);
begin
  FControl.Width := FFromWidth + (FToWidth - FFromWidth) * Progress;
end;

{ TWobbleAnimation }

constructor TWobbleAnimation.Create(AControl: TCastleUserInterface;
  const ADuration: Single; const AAmplitude: Single);
begin
  inherited Create(ADuration);
  FControl := AControl;
  FAmplitude := AAmplitude;
  FOriginX := AControl.Translation.X;
end;

procedure TWobbleAnimation.DoAnimate(const Progress: Single);
var
  Offset: Single;
begin
  Offset := Sin(Progress * Pi * 6) * FAmplitude * (1 - Progress);
  FControl.Translation := Vector2(FOriginX + Offset, FControl.Translation.Y);
end;

procedure TWobbleAnimation.Stop;
begin
  FControl.Translation := Vector2(FOriginX, FControl.Translation.Y);
  inherited;
end;

{ TScaleAnimation }

constructor TScaleAnimation.Create(ALbl: TCastleLabel; const ADuration: Single;
  const AFromScale, AToScale: Single);
begin
  inherited Create(ADuration);
  FLbl := ALbl;
  FFromScale := AFromScale;
  FToScale := AToScale;
end;

procedure TScaleAnimation.Stop;
begin
  FLbl.FontScale := FFromScale;
  inherited;
end;

procedure TScaleAnimation.DoAnimate(const Progress: Single);
begin
  FLbl.FontScale := FFromScale + (FToScale - FFromScale) * Progress;
end;

{ TCountdownPulseAnimation }

constructor TCountdownPulseAnimation.Create(ALbl: TCastleLabel;
  const ADuration: Single);
begin
  inherited Create(ADuration);
  FLbl := ALbl;
  FGrowFraction := 0.2;
  FShrinkFraction := 0.2;
end;

procedure TCountdownPulseAnimation.Stop;
begin
  if FLbl <> nil then
    FLbl.FontScale := 1;
  inherited;
end;

procedure TCountdownPulseAnimation.DoAnimate(const Progress: Single);
const
  BackOvershoot = 2.041896; { 1.70158 * 1.2 - чуть больше отскок }
var
  P, Scale: Single;
begin
  if FLbl = nil then Exit;
  if Progress < FGrowFraction then
  begin
    P := Progress / FGrowFraction;
    P := P - 1;
    Scale := 1 + (BackOvershoot + 1) * P * P * P + BackOvershoot * P * P;
  end
  else if Progress > 1 - FShrinkFraction then
  begin
    P := (Progress - (1 - FShrinkFraction)) / FShrinkFraction;
    P := 1 - P;
    Scale := P * P * P;
  end
  else
    Scale := 1;
  FLbl.FontScale := Scale;
end;

{ TDotsAnimation }

constructor TDotsAnimation.Create(ALabel: TCastleLabel; const ABaseText: string;
  const AInterval: Single);
begin
  inherited Create(1);
  FLabel := ALabel;
  FBaseText := ABaseText;
  FInterval := AInterval;
  FElapsed := 0;
  FDotCount := 0;
end;

procedure TDotsAnimation.Update(const SecondsPassed: Single);
begin
  FElapsed := FElapsed + SecondsPassed;
    if FElapsed >= FInterval then
    begin
      FElapsed := FElapsed - FInterval;
      Inc(FDotCount);
      if FDotCount > 3 then
        FDotCount := 0;
      if FLabel <> nil then
        FLabel.Caption := FBaseText + Copy('...', 1, FDotCount);
    end;
end;

procedure TDotsAnimation.DoAnimate(const Progress: Single);
begin
end;

procedure TDotsAnimation.Stop;
begin
  if FLabel <> nil then
    FLabel.Caption := FBaseText;
  inherited;
end;

procedure TDotsAnimation.Reset(ALabel: TCastleLabel; const ABaseText: String);
begin
  FLabel := ALabel;
  FBaseText := ABaseText;
  FDotCount := 0;
  FElapsed := 0;
  FLabel.Caption := FBaseText;
  Start;
end;

{ TDesignFadeAnimation }

constructor TDesignFadeAnimation.Create(ADesign: TCastleDesign;
  const ADuration: Single; const AFromAlpha, AToAlpha: Single);
var
  I: Integer;
  Child: TCastleUserInterface;
begin
  inherited Create(ADuration);
  FDesign := ADesign;
  FFromAlpha := AFromAlpha;
  FToAlpha := AToAlpha;
  FChildCount := 0;
  SetLength(FChildColors, FDesign.ControlsCount);
  for I := 0 to FDesign.ControlsCount - 1 do
  begin
    Child := FDesign.Controls[I];
    if Child is TCastleLabel then
    begin
      FChildColors[FChildCount].Control := Child;
      FChildColors[FChildCount].OriginalColor := TCastleLabel(Child).Color;
      Inc(FChildCount);
    end
    else if Child is TCastleImageControl then
    begin
      FChildColors[FChildCount].Control := Child;
      FChildColors[FChildCount].OriginalColor := TCastleImageControl(Child).Color;
      Inc(FChildCount);
    end;
  end;
end;

procedure TDesignFadeAnimation.DoAnimate(const Progress: Single);
var
  Alpha: Single;
  I: Integer;
  C: TCastleColor;
begin
  Alpha := FFromAlpha + (FToAlpha - FFromAlpha) * Progress;
  for I := 0 to FChildCount - 1 do
  begin
    C := FChildColors[I].OriginalColor;
    C.W := Alpha;
    if FChildColors[I].Control is TCastleLabel then
      TCastleLabel(FChildColors[I].Control).Color := C
    else
      TCastleImageControl(FChildColors[I].Control).Color := C;
  end;
end;

end.
