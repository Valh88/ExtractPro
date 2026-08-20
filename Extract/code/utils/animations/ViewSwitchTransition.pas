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
    FPhase: (tpFadeOut, tpFadeIn);
    FOnCompleted: TNotifyEvent;
    procedure StartFadeOut;
    procedure StartFadeIn;
    procedure OnFadeOutComplete(Sender: TObject);
    procedure OnFadeInComplete(Sender: TObject);
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
  FPhase := tpFadeOut;
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
  FPhase := tpFadeOut;
  FOverlay.Exists := False;

  if FDelay <= 0 then
    StartFadeOut;
end;

procedure TViewSwitchTransition.StartFadeOut;
var
  FA: TFadeAnimation;
begin
  FPhase := tpFadeOut;
  FOverlay.Color := Vector4(0, 0, 0, 0);
  FOverlay.Exists := True;
  if FFromView <> nil then
    FFromView.InsertFront(FOverlay);

  FA := TFadeAnimation.Create(FOverlay, FDuration, 0, 1);
  FA.OnComplete := @OnFadeOutComplete;
  FAnimManager.Add(FA);
  FA.Start;
end;

procedure TViewSwitchTransition.StartFadeIn;
var
  FA: TFadeAnimation;
begin
  FPhase := tpFadeIn;
  FOverlay.Color := Vector4(0, 0, 0, 1);
  FOverlay.Exists := True;
  if FToView <> nil then
    FToView.InsertFront(FOverlay);

  FA := TFadeAnimation.Create(FOverlay, FDuration, 1, 0);
  FA.OnComplete := @OnFadeInComplete;
  FAnimManager.Add(FA);
  FA.Start;
end;

procedure TViewSwitchTransition.OnFadeOutComplete(Sender: TObject);
begin
  if FFromView <> nil then
    FFromView.RemoveControl(FOverlay);
  if FContainer <> nil then
    FContainer.View := FToView;
  if FToView <> nil then
    StartFadeIn
  else
  begin
    FOverlay.Exists := False;
    if Assigned(FOnCompleted) then
      FOnCompleted(Self);
  end;
end;

procedure TViewSwitchTransition.OnFadeInComplete(Sender: TObject);
begin
  FOverlay.Exists := False;
  if FToView <> nil then
    FToView.RemoveControl(FOverlay);
  if Assigned(FOnCompleted) then
    FOnCompleted(Self);
end;

procedure TViewSwitchTransition.Update(const SecondsPassed: Single);
begin
  if FDelayLeft > 0 then
  begin
    FDelayLeft := FDelayLeft - SecondsPassed;
    if FDelayLeft <= 0 then
      StartFadeOut;
  end;
end;

end.
