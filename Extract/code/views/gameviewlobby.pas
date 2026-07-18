unit GameViewLobby;

interface

uses
  SysUtils, Classes,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse, CastleRectangles,
  LobbyClient, ClientMatchmakingSystem, GameViewPlay, LobbyViewSystem;

type
  TViewLobby = class(TCastleView)
  published
    TopPanel: TCastleRectangleControl;
    GoldGroup: TCastleHorizontalGroup;
    GoldIcon: TCastleImageControl;
    Gold: TCastleLabel;
    MenuTabs: TCastleHorizontalGroup;
    TabPlay: TCastleLabel;
    TabInventory: TCastleLabel;
    TabHeroes: TCastleLabel;
    TabMarket: TCastleLabel;
    RightIcons: TCastleHorizontalGroup;
    Party1: TCastleImageControl;
    Party2: TCastleImageControl;
    PartyMain: TCastleImageControl;
    IconChat: TCastleImageControl;
    IconSettings: TCastleImageControl;
    IconExit: TCastleImageControl;
    BottomPanel: TCastleRectangleControl;
    BottomGradient: TCastleImageControl;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: boolean); override;
    function Press(const Event: TInputPressRelease): Boolean; override;
    function Motion(const Event: TInputMotion): Boolean; override;
    procedure SetLobbyClient(const AValue: TLobbyClient);
  private
    FLobbyClient: TLobbyClient;
  end;

var
  ViewLobby: TViewLobby;

implementation

constructor TViewLobby.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/views/gameviewlobby.castle-user-interface';
end;

procedure TViewLobby.Start;
var
  MM: TClientMatchmakingSystem;
  VP: TViewPlay;
  VS: TLobbyViewSystem;
begin
  inherited;
  if FLobbyClient <> nil then
  begin
    VS := FLobbyClient.ViewSystem;
    TabPlay.OnPress := @VS.OnTabPress;
    TabInventory.OnPress := @VS.OnTabPress;
    TabHeroes.OnPress := @VS.OnTabPress;
    TabMarket.OnPress := @VS.OnTabPress;
    VS.UpdateTabVisuals;

    MM := FLobbyClient.MatchmakingSystem;
    if MM <> nil then
    begin
      VS.GetOrCreateView(lvtPlay);
      VP := VS.ViewPlay;
      if VP <> nil then
        VP.MatchmakingSystem := MM;
    end;
  end;
end;

procedure TViewLobby.Stop;
begin
  FreeAndNil(FLobbyClient);
  inherited;
end;

procedure TViewLobby.Update(const SecondsPassed: Single; var HandleInput: boolean);
begin
  inherited;
  if FLobbyClient <> nil then
    FLobbyClient.Update(SecondsPassed);
end;

function TViewLobby.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited;
  if Result then Exit;
  if FLobbyClient <> nil then
    Result := FLobbyClient.Press(Event);
end;

function TViewLobby.Motion(const Event: TInputMotion): Boolean;
var
  VS: TLobbyViewSystem;
begin
  Result := inherited;
  if Result then Exit;
  if FLobbyClient <> nil then
  begin
    VS := FLobbyClient.ViewSystem;
    if VS <> nil then
      VS.NotifyMotion(Event.Position);
  end;
end;

procedure TViewLobby.SetLobbyClient(const AValue: TLobbyClient);
var
  VS: TLobbyViewSystem;
begin
  FLobbyClient := AValue;
  if FLobbyClient <> nil then
  begin
    VS := FLobbyClient.ViewSystem;
    if VS <> nil then
      VS.View := Self;
  end;
end;

end.
