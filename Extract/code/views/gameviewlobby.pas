unit GameViewLobby;

interface

uses
  SysUtils, Classes, Math,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse, CastleRectangles,
  LobbyClient, ClientMatchmakingSystem, GameViewPlay, LobbyViewSystem,
  ClientEventBus;

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
    ReadyDesign: TCastleDesign;
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
    procedure OnMMState(const Event: TClientGameEvent);
    procedure OnReadyCheck(const Event: TClientGameEvent);
    procedure OnReadyBtn(const Sender: TCastleUserInterface;
      const Event: TInputPressRelease; var Handled: Boolean);
    procedure OnCancelBtn(const Sender: TCastleUserInterface;
      const Event: TInputPressRelease; var Handled: Boolean);
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

    if ReadyDesign <> nil then
    begin
      (ReadyDesign.DesignedComponent('BtnReady') as TCastleButton).OnPress := @Self.OnReadyBtn;
      (ReadyDesign.DesignedComponent('BtnCancel') as TCastleButton).OnPress := @Self.OnCancelBtn;
    end;

    GlobalClientEventBus.Subscribe(cgeMatchmakingStateChanged, @OnMMState);
    GlobalClientEventBus.Subscribe(cgeReadyCheck, @OnReadyCheck);

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
  GlobalClientEventBus.Unsubscribe(@OnMMState);
  GlobalClientEventBus.Unsubscribe(@OnReadyCheck);
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

procedure TViewLobby.OnMMState(const Event: TClientGameEvent);
begin
  SearchDesign.Exists := Event.Amount > 0;
end;

procedure TViewLobby.OnReadyCheck(const Event: TClientGameEvent);
begin
  ReadyDesign.Exists := Event.Amount > 0.5;
end;

procedure TViewLobby.OnReadyBtn(const Sender: TCastleUserInterface;
  const Event: TInputPressRelease; var Handled: Boolean);
begin
  if FLobbyClient <> nil then
  begin
    WriteLn(StdErr, '[Client] Player confirmed ready');
    FLobbyClient.MatchmakingSystem.SendReadyCheck;
  end;
  Handled := True;
end;

procedure TViewLobby.OnCancelBtn(const Sender: TCastleUserInterface;
  const Event: TInputPressRelease; var Handled: Boolean);
begin
  if FLobbyClient <> nil then
  begin
    WriteLn(StdErr, '[Client] Player cancelled ready check');
    FLobbyClient.MatchmakingSystem.SendReadyCancel;
  end;
  Handled := True;
end;

end.
