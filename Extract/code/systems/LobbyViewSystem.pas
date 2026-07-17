unit LobbyViewSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  CastleWindow, CastleUIControls, CastleControls, CastleKeysMouse, CastleColors,
  CastleVectors, Interfaces,
  GameViewPlay, GameViewInventory, ViewTransitionManager, UiAnimation, AnimationManager;

type
  TLobbyViewTab = (lvtPlay, lvtInventory, lvtHeroes, lvtMarket);

  TLobbyViewSystem = class(TInterfacedObject, IWorldSystem)
  private
    FView: TObject;
    FViewPlay: TViewPlay;
    FViewInventory: TViewInventory;
    FActiveView: TCastleView;
    FActiveTab: TLobbyViewTab;
    FTransition: TViewTransitionManager;
    FTabIndicator: TCastleRectangleControl;
    FAnimManager: TAnimationManager;
    FAnimTargetTab: TLobbyViewTab;
    FPhaseDoneCount: Integer;
    FHoveredTab: TLobbyViewTab;
    FActiveColorAnim: TColorAnimation;
    FWobbleAnim: TWobbleAnimation;
    FLastMousePos: TVector2;
    FMouseInContainer: Boolean;
    FSwitchingTabs: Boolean;
    procedure SetActiveTab(const ATab: TLobbyViewTab);
    function GetOrCreateView(const ATab: TLobbyViewTab): TCastleView;
    procedure SetView(const AValue: TObject);
    procedure TransitionCompleted(Sender: TObject);
    procedure OnAnimComplete(Sender: TObject);
    procedure OnHoverAnimComplete(Sender: TObject);
    procedure PhaseCompleted;
    function GetLabelForTab(const ATab: TLobbyViewTab): TCastleLabel;
  public
    constructor Create(AView: TObject);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single);
    function Press(const Event: TInputPressRelease): Boolean;
    procedure UpdateTabVisuals;
    procedure NotifyMotion(const Position: TVector2);
    procedure OnTabPress(const Sender: TCastleUserInterface;
      const Event: TInputPressRelease; var Handled: Boolean);
    property ActiveTab: TLobbyViewTab read FActiveTab write SetActiveTab;
    property View: TObject read FView write SetView;
    property ViewPlay: TViewPlay read FViewPlay;
    property ViewInventory: TViewInventory read FViewInventory;
  end;

implementation

uses GameViewLobby, Math;

const
  ActiveColor: TCastleColor = (X: 0.75; Y: 0.75; Z: 0.75; W: 1.0);
  InactiveColor: TCastleColor = (X: 0.45; Y: 0.45; Z: 0.45; W: 1.0);
  IndicatorColor: TCastleColor = (X: 0.55; Y: 0.10; Z: 0.10; W: 1.0);
  TransitionDuration: Single = 0.3;
  AnimDuration: Single = 0.15;
  HoverAnimDuration: Single = 0.12;
  WobbleDuration: Single = 0.3;
  WobbleAmplitude: Single = 3;

type
  TLobbyViewSystemHelper = class helper for TLobbyViewSystem
  public
    function LobbyView: TViewLobby;
  end;

{ TLobbyViewSystemHelper }

function TLobbyViewSystemHelper.LobbyView: TViewLobby;
begin
  Result := TViewLobby(FView);
end;

{ TLobbyViewSystem }

constructor TLobbyViewSystem.Create(AView: TObject);
begin
  inherited Create;
  FView := AView;
  FViewPlay := nil;
  FViewInventory := nil;
  FActiveView := nil;
  FActiveTab := lvtPlay;
  FTransition := TViewTransitionManager.Create;
  FTransition.OnCompleted := @TransitionCompleted;
  FTabIndicator := TCastleRectangleControl.Create(nil);
  FTabIndicator.Color := IndicatorColor;
  FTabIndicator.Height := 3;
  FAnimManager := TAnimationManager.Create;
  FAnimTargetTab := lvtPlay;
  FPhaseDoneCount := 0;
  FHoveredTab := High(TLobbyViewTab);
  FActiveColorAnim := nil;
  FWobbleAnim := nil;
  FLastMousePos := Vector2(0, 0);
  FMouseInContainer := False;
  FSwitchingTabs := False;
end;

destructor TLobbyViewSystem.Destroy;
begin
  FAnimManager.Free;
  FTransition.Free;
  FreeAndNil(FTabIndicator);
  inherited;
end;

function TLobbyViewSystem.GetLabelForTab(const ATab: TLobbyViewTab): TCastleLabel;
begin
  case ATab of
    lvtPlay: Result := LobbyView.TabPlay;
    lvtInventory: Result := LobbyView.TabInventory;
    lvtHeroes: Result := LobbyView.TabHeroes;
    lvtMarket: Result := LobbyView.TabMarket;
  end;
end;

function TLobbyViewSystem.GetOrCreateView(const ATab: TLobbyViewTab): TCastleView;
begin
  case ATab of
    lvtPlay:
    begin
      if FViewPlay = nil then FViewPlay := TViewPlay.Create(Application);
      Result := FViewPlay;
    end;
    lvtInventory:
    begin
      if FViewInventory = nil then FViewInventory := TViewInventory.Create(Application);
      Result := FViewInventory;
    end;
  else
    Result := nil;
  end;
end;

procedure TLobbyViewSystem.TransitionCompleted(Sender: TObject);
begin
  FActiveView := GetOrCreateView(FActiveTab);
  FSwitchingTabs := False;
end;

procedure TLobbyViewSystem.OnAnimComplete(Sender: TObject);
begin
  Inc(FPhaseDoneCount);
  if FPhaseDoneCount >= 2 then
  begin
    FPhaseDoneCount := 0;
    PhaseCompleted;
  end;
end;

procedure TLobbyViewSystem.OnHoverAnimComplete(Sender: TObject);
begin
  FActiveColorAnim := nil;
end;

procedure TLobbyViewSystem.PhaseCompleted;
var
  NewLabel: TCastleLabel;
  OldView: TCastleView;
  TargetView: TCastleView;
  Container: TCastleContainer;
  WA: TWidthAnimation;
  CA: TColorAnimation;
begin
  if FAnimTargetTab <> FActiveTab then
  begin
    // Phase 1 done — reparent indicator, start Phase 2
    FActiveTab := FAnimTargetTab;
    NewLabel := GetLabelForTab(FActiveTab);
    if NewLabel = nil then Exit;

    NewLabel.InsertFront(FTabIndicator);
    FTabIndicator.Anchor(hpMiddle);
    FTabIndicator.Anchor(vpTop, vpBottom, -6);
    FTabIndicator.Width := 0;
    FTabIndicator.Translation := Vector2(0, FTabIndicator.Translation.Y);

    WA := TWidthAnimation.Create(FTabIndicator, AnimDuration,
      0, NewLabel.EffectiveWidth);
    WA.OnComplete := @OnAnimComplete;
    FAnimManager.Add(WA);
    WA.Start;

    CA := TColorAnimation.Create(NewLabel, AnimDuration,
      InactiveColor, ActiveColor);
    CA.OnComplete := @OnAnimComplete;
    FAnimManager.Add(CA);
    CA.Start;
  end
  else
  begin
    // Phase 2 done — both animations complete, switch view
    FAnimTargetTab := lvtPlay;
    UpdateTabVisuals;

    OldView := FActiveView;
    if (OldView <> nil) and (LobbyView <> nil) then
    begin
      Container := LobbyView.Container;
      if Container = nil then Exit;
      TargetView := GetOrCreateView(FActiveTab);
      FActiveView := nil;
      FTransition.StartTransition(Container, OldView, TargetView, TransitionDuration);
    end;
  end;
end;

procedure TLobbyViewSystem.Update(const SecondsPassed: Single);
var
  Container: TCastleContainer;
  TargetView: TCastleView;
  i: TLobbyViewTab;
  Lbl: TCastleLabel;
  HoverFound: Boolean;
begin
  if FView = nil then Exit;

  FAnimManager.Update(SecondsPassed);
  if (FActiveColorAnim <> nil) and FActiveColorAnim.IsComplete then
    FActiveColorAnim := nil;
  if (FWobbleAnim <> nil) and FWobbleAnim.IsComplete then
    FWobbleAnim := nil;

  if (not FTransition.IsActive) and (not FSwitchingTabs) then
  begin
    HoverFound := False;
    if FMouseInContainer then
    begin
      for i := Low(TLobbyViewTab) to High(TLobbyViewTab) do
      begin
        Lbl := GetLabelForTab(i);
        if (Lbl <> nil) and Lbl.RenderRect.Contains(FLastMousePos) then
        begin
          HoverFound := True;
          if FHoveredTab <> i then
          begin
            if FActiveColorAnim <> nil then
            begin
              FActiveColorAnim.Stop;
              FActiveColorAnim := nil;
            end;
            if FWobbleAnim <> nil then
            begin
              FWobbleAnim.Stop;
              FWobbleAnim := nil;
            end;
            if (FHoveredTab <= High(TLobbyViewTab)) and (FHoveredTab <> FActiveTab) then
            begin
              Lbl := GetLabelForTab(FHoveredTab);
              if Lbl <> nil then
                Lbl.Color := InactiveColor;
            end;
            FHoveredTab := i;
            if i <> FActiveTab then
            begin
              Lbl := GetLabelForTab(i);
              FActiveColorAnim := TColorAnimation.Create(Lbl, HoverAnimDuration,
                Lbl.Color, ActiveColor);
              FActiveColorAnim.OnComplete := @OnHoverAnimComplete;
              FActiveColorAnim.Start;
              FAnimManager.Add(FActiveColorAnim);
              FWobbleAnim := TWobbleAnimation.Create(Lbl, WobbleDuration, WobbleAmplitude);
              FWobbleAnim.Start;
              FAnimManager.Add(FWobbleAnim);
            end;
          end;
          Break;
        end;
      end;
    end;

    if not HoverFound then
    begin
      if FActiveColorAnim <> nil then
      begin
        FActiveColorAnim.Stop;
        FActiveColorAnim := nil;
      end;
      if FWobbleAnim <> nil then
      begin
        FWobbleAnim.Stop;
        FWobbleAnim := nil;
      end;
      if (FHoveredTab <= High(TLobbyViewTab)) and (FHoveredTab <> FActiveTab) then
      begin
        Lbl := GetLabelForTab(FHoveredTab);
        if Lbl <> nil then
          Lbl.Color := InactiveColor;
      end;
      FHoveredTab := High(TLobbyViewTab);
    end;
  end;

  if FTransition.IsActive then
  begin
    FTransition.Update(SecondsPassed);
    Exit;
  end;

  if FActiveView = nil then
  begin
    Container := LobbyView.Container;
    if Container = nil then Exit;
    TargetView := GetOrCreateView(FActiveTab);
    Container.PushView(TargetView);
    FActiveView := TargetView;
  end;
end;

function TLobbyViewSystem.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := False;
end;

procedure TLobbyViewSystem.OnTabPress(const Sender: TCastleUserInterface;
  const Event: TInputPressRelease; var Handled: Boolean);
begin
  if Sender = LobbyView.TabPlay then
    SetActiveTab(lvtPlay)
  else if Sender = LobbyView.TabInventory then
    SetActiveTab(lvtInventory)
  else
    Exit;
  Handled := True;
end;

procedure TLobbyViewSystem.NotifyMotion(const Position: TVector2);
begin
  FLastMousePos := Position;
  FMouseInContainer := True;
end;

procedure TLobbyViewSystem.SetView(const AValue: TObject);
begin
  FView := AValue;
end;

procedure TLobbyViewSystem.UpdateTabVisuals;
var
  i: TLobbyViewTab;
begin
  for i := Low(TLobbyViewTab) to High(TLobbyViewTab) do
    GetLabelForTab(i).Color := InactiveColor;
  GetLabelForTab(FActiveTab).Color := ActiveColor;

  if FTabIndicator.Parent <> GetLabelForTab(FActiveTab) then
    GetLabelForTab(FActiveTab).InsertFront(FTabIndicator);
  FTabIndicator.Height := 3;
  FTabIndicator.Width := GetLabelForTab(FActiveTab).EffectiveWidth;
  FTabIndicator.Anchor(hpMiddle);
  FTabIndicator.Anchor(vpTop, vpBottom, -6);
  FTabIndicator.Translation := Vector2(0, FTabIndicator.Translation.Y);
end;

procedure TLobbyViewSystem.SetActiveTab(const ATab: TLobbyViewTab);
var
  OldLabel: TCastleLabel;
  WA: TWidthAnimation;
  CA: TColorAnimation;
begin
  if FActiveTab = ATab then Exit;
  if FTransition.IsActive then Exit;
  if FSwitchingTabs then Exit;

  OldLabel := GetLabelForTab(FActiveTab);
  if OldLabel = nil then Exit;

  FAnimTargetTab := ATab;
  FPhaseDoneCount := 0;
  FSwitchingTabs := True;
  FActiveColorAnim := nil;
  if FWobbleAnim <> nil then
  begin
    FWobbleAnim.Stop;
    FWobbleAnim := nil;
  end;
  FAnimManager.Clear;

  OldLabel.InsertFront(FTabIndicator);
  FTabIndicator.Anchor(hpMiddle);
  FTabIndicator.Anchor(vpTop, vpBottom, -6);
  FTabIndicator.Translation := Vector2(0, FTabIndicator.Translation.Y);

  WA := TWidthAnimation.Create(FTabIndicator, AnimDuration,
    FTabIndicator.Width, 0);
  WA.OnComplete := @OnAnimComplete;
  FAnimManager.Add(WA);
  WA.Start;

  CA := TColorAnimation.Create(OldLabel, AnimDuration,
    ActiveColor, InactiveColor);
  CA.OnComplete := @OnAnimComplete;
  FAnimManager.Add(CA);
  CA.Start;
end;

end.
