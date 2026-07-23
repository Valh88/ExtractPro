unit ViewSwitchTransition;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, CastleUIControls, CastleControls, CastleVectors,
  CastleRectangles, UiAnimation, AnimationManager;

type
  TViewSwitchTransition = class
  private
    FContainer: TCastleContainer;
    FFromView: TCastleView;
    FToView: TCastleView;
    FOverlay: TCastleRectangleControl;
    FAnimManager: TAnimationManager;
    FDuration: Single;
    FDelay: Single;
    FDelayLeft: Single;
    FOnCompleted: TNotifyEvent;
    procedure StartFade;
    procedure OnFadeOutComplete(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start(AContainer: TCastleContainer;
      AFromView, AToView: TCastleView;
      AAnimManager: TAnimationManager;
      const ADuration: Single = 0.3; const ADelay: Single = 0.0);
    procedure Update(const SecondsPassed: Single);
    property OnCompleted: TNotifyEvent read FOnCompleted write FOnCompleted;
  end;

implementation

{ TViewSwitchTransition }

constructor TViewSwitchTransition.Create;
begin
  inherited Create;
  FContainer := nil;
  FFromView := nil;
  FToView := nil;
  FAnimManager := nil;
  FDuration := 0.3;
  FDelay := 0;
  FDelayLeft := 0;
  FOnCompleted := nil;
  FOverlay := TCastleRectangleControl.Create(nil);
  FOverlay.FullSize := True;
  FOverlay.Color := Vector4(0, 0, 0, 0);
  FOverlay.Exists := False;
end;

destructor TViewSwitchTransition.Destroy;
begin
  FreeAndNil(FOverlay);
  inherited;
end;

procedure TViewSwitchTransition.Start(AContainer: TCastleContainer;
  AFromView, AToView: TCastleView;
  AAnimManager: TAnimationManager;
  const ADuration: Single; const ADelay: Single);
begin
  FContainer := AContainer;
  FFromView := AFromView;
  FToView := AToView;
  FAnimManager := AAnimManager;
  FDuration := ADuration;
  FDelay := ADelay;
  FDelayLeft := ADelay;
  FOverlay.Exists := False;

  if FDelay <= 0 then
    StartFade;
end;

procedure TViewSwitchTransition.StartFade;
var
  FA: TFadeAnimation;
begin
  FOverlay.Color := Vector4(0, 0, 0, 0);
  FOverlay.Exists := True;
  if FFromView <> nil then
    FFromView.InsertFront(FOverlay);

  FA := TFadeAnimation.Create(FOverlay, FDuration, 0, 1);
  FA.OnComplete := @OnFadeOutComplete;
  FAnimManager.Add(FA);
  FA.Start;
end;

procedure TViewSwitchTransition.OnFadeOutComplete(Sender: TObject);
begin
  FOverlay.Exists := False;
  if FFromView <> nil then
    FFromView.RemoveControl(FOverlay);
  if FContainer <> nil then
    FContainer.View := FToView;
  if Assigned(FOnCompleted) then
    FOnCompleted(Self);
end;

procedure TViewSwitchTransition.Update(const SecondsPassed: Single);
begin
  if FDelayLeft > 0 then
  begin
    FDelayLeft := FDelayLeft - SecondsPassed;
    if FDelayLeft <= 0 then
      StartFade;
  end;
end;

end.
