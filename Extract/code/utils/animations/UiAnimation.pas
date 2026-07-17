unit UiAnimation;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, CastleUIControls, CastleControls, CastleVectors;

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

end.
