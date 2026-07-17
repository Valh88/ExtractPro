unit UiAnimation;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, CastleUIControls, CastleControls, CastleVectors, CastleColors;

type
  TUiAnimation = class
  private
    FDuration: Single;
    FProgress: Single;
    FOnComplete: TNotifyEvent;
  protected
    procedure DoAnimate(const Progress: Single); virtual; abstract;
  public
    constructor Create(const ADuration: Single);
    procedure Update(const SecondsPassed: Single);
    procedure Start;
    procedure Stop;
    function IsComplete: Boolean;
    property Duration: Single read FDuration write FDuration;
    property OnComplete: TNotifyEvent read FOnComplete write FOnComplete;
  end;

  TFadeAnimation = class(TUiAnimation)
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

  TColorAnimation = class(TUiAnimation)
  private
    FLabel: TCastleLabel;
    FFromColor, FToColor: TVector4;
  protected
    procedure DoAnimate(const Progress: Single); override;
  public
    constructor Create(ALabel: TCastleLabel; const ADuration: Single;
      const AFromColor, AToColor: TVector4);
  end;

  TWidthAnimation = class(TUiAnimation)
  private
    FControl: TCastleUserInterface;
    FFromWidth, FToWidth: Single;
  protected
    procedure DoAnimate(const Progress: Single); override;
  public
    constructor Create(AControl: TCastleUserInterface; const ADuration: Single;
      const AFromWidth, AToWidth: Single);
  end;

implementation

{ TUiAnimation }

constructor TUiAnimation.Create(const ADuration: Single);
begin
  inherited Create;
  FDuration := ADuration;
  FProgress := 0;
  FOnComplete := nil;
end;

procedure TUiAnimation.Start;
begin
  FProgress := 0;
end;

procedure TUiAnimation.Stop;
begin
  FProgress := 1;
end;

function TUiAnimation.IsComplete: Boolean;
begin
  Result := FProgress >= 1;
end;

procedure TUiAnimation.Update(const SecondsPassed: Single);
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

end.
