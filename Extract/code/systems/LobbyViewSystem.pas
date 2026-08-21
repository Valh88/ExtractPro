unit LobbyViewSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  CastleWindow, CastleUIControls, CastleControls, CastleKeysMouse, CastleColors,
  CastleVectors, Interfaces,
  GameViewPlay, GameViewInventory, GameViewMarket, ViewTransitionManager, UiAnimation, AnimationManager;

type
  TLobbyViewTab = (lvtPlay, lvtInventory, lvtHeroes, lvtMarket, lvtCount);

  TLobbyViewSystem = class(TInterfacedObject, IWorldSystem)
  private
    FView: TObject;
    FViewPlay: TViewPlay;
    FViewInventory: TViewInventory;
    FViewMarket: TViewMarket;
    FActiveView: TCastleView;
    FActiveTab: TLobbyViewTab;
    FTransition: TViewTransitionManager;
    FTabIndicator: TCastleRectangleControl;
    FAnimManager: TAnimationManager;
    FAnimTargetTab: TLobbyViewTab;
    FPhaseDoneCount: Integer;
    FHoveredTab: TLobbyViewTab;
    FHoverScaleAnim: TScaleAnimation;
    FLastMousePos: TVector2;
    FMouseInContainer: Boolean;
    FSwitchingTabs: Boolean;
    procedure SetActiveTab(const ATab: TLobbyViewTab);
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
    procedure EnsureActiveView;
    function GetOrCreateView(const ATab: TLobbyViewTab): TCastleView;
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
  HoverAnimDuration: Single = 0.15;
  HoverScaleFrom: Single = 1.0;
  HoverScaleTo: Single = 1.15;

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
  FViewMarket := nil;
  FActiveView := nil;
  FActiveTab := lvtInventory;
  FTransition := TViewTransitionManager.Create;
  FTransition.OnCompleted := @TransitionCompleted;
  FTabIndicator := TCastleRectangleControl.Create(nil);
  FTabIndicator.Color := IndicatorColor;
  FTabIndicator.Height := 3;
  FAnimManager := TAnimationManager.Create;
  FAnimTargetTab := lvtPlay;
  FPhaseDoneCount := 0;
  FHoveredTab := lvtCount;
  FHoverScaleAnim := nil;
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
  else
    Result := nil;
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
    lvtMarket:
    begin
      if FViewMarket = nil then FViewMarket := TViewMarket.Create(Application);
      Result := FViewMarket;
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
  FHoverScaleAnim := nil;
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
  if (FHoverScaleAnim <> nil) and FHoverScaleAnim.IsComplete then
    FHoverScaleAnim := nil;

  if (not FTransition.IsActive) and (not FSwitchingTabs) then
  begin
    HoverFound := False;
    if FMouseInContainer then
    begin
      for i := Low(TLobbyViewTab) to Pred(lvtCount) do
      begin
        Lbl := GetLabelForTab(i);
        if (Lbl <> nil) and Lbl.RenderRect.Contains(FLastMousePos) then
        begin
          HoverFound := True;
          if FHoveredTab <> i then
          begin
            if FHoverScaleAnim <> nil then
            begin
              FHoverScaleAnim.Stop;
              FHoverScaleAnim := nil;
            end;
            if (FHoveredTab < lvtCount) and (FHoveredTab <> FActiveTab) then
            begin
              Lbl := GetLabelForTab(FHoveredTab);
              if Lbl <> nil then
                Lbl.FontScale := HoverScaleFrom;
            end;
            FHoveredTab := i;
            if i <> FActiveTab then
            begin
              Lbl := GetLabelForTab(i);
              FHoverScaleAnim := TScaleAnimation.Create(Lbl, HoverAnimDuration,
                HoverScaleFrom, HoverScaleTo);
              FHoverScaleAnim.OnComplete := @OnHoverAnimComplete;
              FHoverScaleAnim.Start;
              FAnimManager.Add(FHoverScaleAnim);
            end;
          end;
          Break;
        end;
      end;
    end;

    if not HoverFound then
    begin
      if FHoverScaleAnim <> nil then
      begin
        FHoverScaleAnim.Stop;
        FHoverScaleAnim := nil;
      end;
      if (FHoveredTab < lvtCount) and (FHoveredTab <> FActiveTab) then
      begin
        Lbl := GetLabelForTab(FHoveredTab);
        if Lbl <> nil then
          Lbl.FontScale := HoverScaleFrom;
      end;
      FHoveredTab := lvtCount;
    end;
  end;

  if FTransition.IsActive then
  begin
    FTransition.Update(SecondsPassed);
    Exit;
  end;

  if FActiveView = nil then
    EnsureActiveView;
end;

procedure TLobbyViewSystem.EnsureActiveView;
var
  Container: TCastleContainer;
  TargetView: TCastleView;
begin
  if FActiveView <> nil then Exit;
  Container := LobbyView.Container;
  if Container = nil then Exit;
  TargetView := GetOrCreateView(FActiveTab);
  Container.PushView(TargetView);
  FActiveView := TargetView;
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
  else if Sender = LobbyView.TabHeroes then
    SetActiveTab(lvtHeroes)
  else if Sender = LobbyView.TabMarket then
    SetActiveTab(lvtMarket)
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
  for i := Low(TLobbyViewTab) to Pred(lvtCount) do
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
  i: TLobbyViewTab;
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
  FHoverScaleAnim := nil;
  for i := Low(TLobbyViewTab) to Pred(lvtCount) do
    GetLabelForTab(i).FontScale := HoverScaleFrom;
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
