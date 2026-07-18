unit GameViewLobby;

interface

uses
  SysUtils, Classes, Math,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse, CastleRectangles,
  LobbyClient, ClientMatchmakingSystem, GameViewPlay, LobbyViewSystem,
  EventBus;

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
    SearchDesign: TCastleDesign;
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
    FSpinnerImage: TCastleImageControl;
    procedure OnMMState(const Event: TGameEvent);
  end;

const
  SpinnerRotationSpeed = 5.0;

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

    FSpinnerImage := SearchDesign.DesignedComponent('SpinnerImage') as TCastleImageControl;

    GlobalEventBus.Subscribe(geMatchmakingStateChanged, @OnMMState);

    VS.GetOrCreateView(lvtPlay);
    VP := VS.ViewPlay;
    if VP <> nil then
    begin
      MM := FLobbyClient.MatchmakingSystem;
      VP.MatchmakingSystem := MM;
    end;
  end;
end;

procedure TViewLobby.Stop;
begin
  GlobalEventBus.Unsubscribe(@OnMMState);
  FreeAndNil(FLobbyClient);
  inherited;
end;

procedure TViewLobby.Update(const SecondsPassed: Single; var HandleInput: boolean);
begin
  inherited;
  if FLobbyClient <> nil then
  begin
    FLobbyClient.Update(SecondsPassed);
    if (FSpinnerImage <> nil) and SearchDesign.Exists then
      FSpinnerImage.Rotation := FSpinnerImage.Rotation + SecondsPassed * SpinnerRotationSpeed;
  end;
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

procedure TViewLobby.OnMMState(const Event: TGameEvent);
begin
  SearchDesign.Exists := Event.Amount > 0;
end;

end.
