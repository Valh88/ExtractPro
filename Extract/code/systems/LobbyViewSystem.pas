unit LobbyViewSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  CastleWindow, CastleUIControls, CastleControls, CastleKeysMouse, CastleColors,
  CastleVectors, Interfaces,
  GameViewPlay, GameViewInventory, ViewTransitionManager;

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
    procedure SetActiveTab(const ATab: TLobbyViewTab);
    function GetOrCreateView(const ATab: TLobbyViewTab): TCastleView;
    procedure SetView(const AValue: TObject);
    procedure TransitionCompleted(Sender: TObject);
  public
    constructor Create(AView: TObject);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single);
    function Press(const Event: TInputPressRelease): Boolean;
    procedure UpdateTabVisuals;
    procedure OnTabPress(const Sender: TCastleUserInterface;
      const Event: TInputPressRelease; var Handled: Boolean);
    property ActiveTab: TLobbyViewTab read FActiveTab write SetActiveTab;
    property View: TObject read FView write SetView;
    property ViewPlay: TViewPlay read FViewPlay;
    property ViewInventory: TViewInventory read FViewInventory;
  end;

implementation

uses GameViewLobby;

const
  ActiveColor: TCastleColor = (X: 0.75; Y: 0.75; Z: 0.75; W: 1.0);
  InactiveColor: TCastleColor = (X: 0.45; Y: 0.45; Z: 0.45; W: 1.0);
  IndicatorColor: TCastleColor = (X: 0.55; Y: 0.10; Z: 0.10; W: 1.0);
  TransitionDuration: Single = 0.3;

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
end;

destructor TLobbyViewSystem.Destroy;
begin
  FTransition.Free;
  FreeAndNil(FTabIndicator);
  inherited;
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
end;

procedure TLobbyViewSystem.Update(const SecondsPassed: Single);
var
  Container: TCastleContainer;
  TargetView: TCastleView;
begin
  if FView = nil then Exit;

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

procedure TLobbyViewSystem.SetView(const AValue: TObject);
begin
  FView := AValue;
end;

procedure TLobbyViewSystem.UpdateTabVisuals;
var
  ActiveLabel: TCastleLabel;
begin
  LobbyView.TabPlay.Color := InactiveColor;
  LobbyView.TabInventory.Color := InactiveColor;
  LobbyView.TabHeroes.Color := InactiveColor;
  LobbyView.TabMarket.Color := InactiveColor;
  ActiveLabel := nil;
  case FActiveTab of
    lvtPlay:
    begin
      LobbyView.TabPlay.Color := ActiveColor;
      ActiveLabel := LobbyView.TabPlay;
    end;
    lvtInventory:
    begin
      LobbyView.TabInventory.Color := ActiveColor;
      ActiveLabel := LobbyView.TabInventory;
    end;
    lvtHeroes:
    begin
      LobbyView.TabHeroes.Color := ActiveColor;
      ActiveLabel := LobbyView.TabHeroes;
    end;
    lvtMarket:
    begin
      LobbyView.TabMarket.Color := ActiveColor;
      ActiveLabel := LobbyView.TabMarket;
    end;
  end;
  if ActiveLabel <> nil then
  begin
    FTabIndicator.Height := 3;
    FTabIndicator.Width := ActiveLabel.EffectiveWidth;
    FTabIndicator.Anchor(hpLeft);
    FTabIndicator.Anchor(vpTop, vpBottom, -6);
    if FTabIndicator.Parent <> ActiveLabel then
      ActiveLabel.InsertFront(FTabIndicator);
  end
  else
  begin
    if FTabIndicator.Parent <> nil then
      FTabIndicator.Parent.RemoveControl(FTabIndicator);
  end;
end;

procedure TLobbyViewSystem.SetActiveTab(const ATab: TLobbyViewTab);
var
  OldView: TCastleView;
  TargetView: TCastleView;
  Container: TCastleContainer;
begin
  if FActiveTab = ATab then Exit;
  if FTransition.IsActive then Exit;

  FActiveTab := ATab;
  UpdateTabVisuals;

  OldView := FActiveView;
  if (OldView <> nil) and (LobbyView <> nil) then
  begin
    Container := LobbyView.Container;
    if Container = nil then Exit;
    TargetView := GetOrCreateView(ATab);
    FActiveView := nil;
    FTransition.StartTransition(Container, OldView, TargetView, TransitionDuration);
  end;
end;

end.
