unit ViewTransitionManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, CastleUIControls, CastleControls, CastleRectangles,
  CastleVectors, UiAnimation;

type
  TViewTransitionManager = class
  private
    FContainer: TCastleContainer;
    FFromView: TCastleView;
    FToView: TCastleView;
    FOverlay: TCastleRectangleControl;
    FCurrentAnimation: TBaseAnimation;
    FFadeDuration: Single;
    FOnCompleted: TNotifyEvent;
    procedure FadeOutComplete(Sender: TObject);
    procedure FadeInComplete(Sender: TObject);
    function GetIsActive: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure StartTransition(AContainer: TCastleContainer;
      AFromView, AToView: TCastleView; const ADuration: Single);
    procedure Update(const SecondsPassed: Single);
    procedure Cancel;
    property OnCompleted: TNotifyEvent read FOnCompleted write FOnCompleted;
    property IsActive: Boolean read GetIsActive;
  end;

implementation

constructor TViewTransitionManager.Create;
begin
  inherited Create;
  FContainer := nil;
  FFromView := nil;
  FToView := nil;
  FOverlay := TCastleRectangleControl.Create(nil);
  FOverlay.FullSize := False;
  FOverlay.Color := Vector4(0, 0, 0, 0);
  FCurrentAnimation := nil;
  FOnCompleted := nil;
  FFadeDuration := 0.3;
end;

destructor TViewTransitionManager.Destroy;
begin
  Cancel;
  FreeAndNil(FOverlay);
  inherited;
end;

procedure TViewTransitionManager.StartTransition(AContainer: TCastleContainer;
  AFromView, AToView: TCastleView; const ADuration: Single);
begin
  Cancel;
  FContainer := AContainer;
  FFromView := AFromView;
  FToView := AToView;
  FFadeDuration := ADuration;
  if FContainer = nil then
  begin
    if Assigned(FOnCompleted) then
      FOnCompleted(Self);
    Exit;
  end;
  FOverlay.Color := Vector4(0, 0, 0, 0);
  if FFromView <> nil then
  begin
    FFromView.InsertFront(FOverlay);
    FOverlay.Anchor(hpLeft);
    FOverlay.WidthFraction := 1;
    FOverlay.Anchor(vpBottom, 70);
    FOverlay.Height := FFromView.EffectiveHeight - 140;
    if FOverlay.Height < 0 then FOverlay.Height := 0;
  end;
  FCurrentAnimation := TFadeAnimation.Create(FOverlay, FFadeDuration, 0, 1);
  FCurrentAnimation.OnComplete := @FadeOutComplete;
  FCurrentAnimation.Start;
end;

procedure TViewTransitionManager.FadeOutComplete(Sender: TObject);
begin
  FreeAndNil(FCurrentAnimation);
  if FFromView <> nil then
  begin
    FFromView.RemoveControl(FOverlay);
    FContainer.PopView;
  end;
  FOverlay.Color := Vector4(0, 0, 0, 1);
  if FToView <> nil then
  begin
    FToView.InsertFront(FOverlay);
    FOverlay.Anchor(hpLeft);
    FOverlay.WidthFraction := 1;
    FOverlay.Anchor(vpBottom, 70);
    FOverlay.Height := FToView.EffectiveHeight - 140;
    if FOverlay.Height < 0 then FOverlay.Height := 0;
    FContainer.PushView(FToView);
  end;
  FCurrentAnimation := TFadeAnimation.Create(FOverlay, FFadeDuration, 1, 0);
  FCurrentAnimation.OnComplete := @FadeInComplete;
  FCurrentAnimation.Start;
end;

procedure TViewTransitionManager.FadeInComplete(Sender: TObject);
begin
  FreeAndNil(FCurrentAnimation);
  if FToView <> nil then
    FToView.RemoveControl(FOverlay);
  if Assigned(FOnCompleted) then
    FOnCompleted(Self);
end;

procedure TViewTransitionManager.Update(const SecondsPassed: Single);
begin
  if FCurrentAnimation <> nil then
    FCurrentAnimation.Update(SecondsPassed);
end;

procedure TViewTransitionManager.Cancel;
begin
  FreeAndNil(FCurrentAnimation);
  if FOverlay = nil then Exit;
  if (FFromView <> nil) then
    FFromView.RemoveControl(FOverlay);
  if (FToView <> nil) then
    FToView.RemoveControl(FOverlay);
end;

function TViewTransitionManager.GetIsActive: Boolean;
begin
  Result := FCurrentAnimation <> nil;
end;

end.
