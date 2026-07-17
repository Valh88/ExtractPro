unit LobbyViewSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  CastleWindow, CastleUIControls, CastleKeysMouse, CastleColors, Interfaces,
  GameViewPlay, GameViewInventory;

type
  TLobbyViewTab = (lvtPlay, lvtInventory, lvtHeroes, lvtMarket);

  TLobbyViewSystem = class(TInterfacedObject, IWorldSystem)
  private
    FView: TObject;
    FViewPlay: TViewPlay;
    FViewInventory: TViewInventory;
    FActiveTab: TLobbyViewTab;
    procedure SetActiveTab(const ATab: TLobbyViewTab);
    procedure ShowTabView(const AView: TCastleView);
    procedure SetView(const AValue: TObject);
  public
    constructor Create(AView: TObject);
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
  FActiveTab := lvtPlay;
end;

procedure TLobbyViewSystem.ShowTabView(const AView: TCastleView);
var
  Container: TCastleContainer;
begin
  Container := LobbyView.Container;
  if Container = nil then Exit;
  if Container.CurrentFrontView <> AView then
  begin
    if Container.CurrentViewStackCount > 1 then
      Container.PopView;
    Container.PushView(AView);
  end;
end;

procedure TLobbyViewSystem.Update(const SecondsPassed: Single);
begin
  if FView = nil then Exit;
  case FActiveTab of
    lvtPlay:
    begin
      if FViewPlay = nil then FViewPlay := TViewPlay.Create(Application);
      ShowTabView(FViewPlay);
    end;
    lvtInventory:
    begin
      if FViewInventory = nil then FViewInventory := TViewInventory.Create(Application);
      ShowTabView(FViewInventory);
    end;
    lvtHeroes, lvtMarket: ; // TODO
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
begin
  LobbyView.TabPlay.Color := InactiveColor;
  LobbyView.TabInventory.Color := InactiveColor;
  LobbyView.TabHeroes.Color := InactiveColor;
  LobbyView.TabMarket.Color := InactiveColor;
  case FActiveTab of
    lvtPlay: LobbyView.TabPlay.Color := ActiveColor;
    lvtInventory: LobbyView.TabInventory.Color := ActiveColor;
    lvtHeroes: LobbyView.TabHeroes.Color := ActiveColor;
    lvtMarket: LobbyView.TabMarket.Color := ActiveColor;
  end;
end;

procedure TLobbyViewSystem.SetActiveTab(const ATab: TLobbyViewTab);
begin
  if FActiveTab = ATab then Exit;
  FActiveTab := ATab;
  UpdateTabVisuals;
end;

end.
