unit GameViewLobby;

interface

uses
  SysUtils, Classes, Math,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse, CastleRectangles,
  LobbyClient, ClientMatchmakingSystem, GameViewPlay, LobbyViewSystem,
  ClientEventBus, GameViewMain;

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
    CheckReadingPlayersDesign: TCastleDesign;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: boolean); override;
    function Press(const Event: TInputPressRelease): Boolean; override;
    function Motion(const Event: TInputMotion): Boolean; override;
    procedure SetLobbyClient(const AValue: TLobbyClient);
  private
    type
      TCheckSlot = record
        PlayerId: UInt32;
        Design: TCastleDesign;
      end;
    var
      FLobbyClient: TLobbyClient;
      FSpinnerImage: TCastleImageControl;
      FPlayerGroup: TCastleVerticalGroup;
      FCheckPanelBg: TCastleImageControl;
      FCheckSlots: array of TCheckSlot;
    procedure OnMMState(const Event: TClientGameEvent);
    procedure OnReadyCheck(const Event: TClientGameEvent);
    procedure OnReadyCheckUpdate(const Event: TClientGameEvent);
    procedure OnReadyBtn(const Sender: TCastleUserInterface;
      const Event: TInputPressRelease; var Handled: Boolean);
    procedure OnCancelBtn(const Sender: TCastleUserInterface;
      const Event: TInputPressRelease; var Handled: Boolean);
    procedure OnStartGame(const Event: TClientGameEvent);
    procedure ClearCheckSlots;
  end;

const
  SpinnerRotationSpeed = 5.0;
  MaxSlotsPerRow = 6;

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

    if CheckReadingPlayersDesign <> nil then
    begin
      FPlayerGroup := CheckReadingPlayersDesign.DesignedComponent('PlayerGroup') as TCastleVerticalGroup;
      FCheckPanelBg := CheckReadingPlayersDesign.DesignedComponent('CheckPanelBg') as TCastleImageControl;
    end;

    GlobalClientEventBus.Subscribe(cgeMatchmakingStateChanged, @OnMMState);
    GlobalClientEventBus.Subscribe(cgeReadyCheck, @OnReadyCheck);
    GlobalClientEventBus.Subscribe(cgeReadyCheckUpdate, @OnReadyCheckUpdate);
    GlobalClientEventBus.Subscribe(cgeStartGame, @OnStartGame);

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
  GlobalClientEventBus.Unsubscribe(@OnReadyCheckUpdate);
  GlobalClientEventBus.Unsubscribe(@OnStartGame);
  ClearCheckSlots;
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
  SearchDesign.Exists := (Event.Amount > 0) and (Event.Amount < 2.0);
end;

procedure TViewLobby.OnReadyCheck(const Event: TClientGameEvent);
begin
  if (Event.Amount > 0.5) and (Event.Amount < 1.5) then
  begin
    ReadyDesign.Exists := True;
    // CheckReadingPlayersDesign shown only after clicking "PLAY"
  end
  else
  begin
    ReadyDesign.Exists := False;
    if CheckReadingPlayersDesign <> nil then
    begin
      CheckReadingPlayersDesign.Exists := False;
      ClearCheckSlots;
    end;
  end;
end;

procedure TViewLobby.OnReadyCheckUpdate(const Event: TClientGameEvent);
var
  Payload: TReadyCheckUpdatePayload;
  i, j, TotalPlayers, InRow, RowCount: Integer;
  Slot: TCastleDesign;
  Row: TCastleHorizontalGroup;
begin
  Payload := TReadyCheckUpdatePayload(Event.Data);
  if Payload = nil then Exit;

  ClearCheckSlots;
  if FPlayerGroup = nil then
  begin
    Payload.Free;
    Exit;
  end;

  TotalPlayers := Length(Payload.Players);
  if TotalPlayers = 0 then
  begin
    Payload.Free;
    Exit;
  end;

  RowCount := (TotalPlayers + MaxSlotsPerRow - 1) div MaxSlotsPerRow;
  SetLength(FCheckSlots, TotalPlayers);

  for i := 0 to RowCount - 1 do
  begin
    Row := TCastleHorizontalGroup.Create(Self);
    Row.Spacing := 10;
    Row.VerticalAnchorParent := vpMiddle;
    Row.VerticalAnchorSelf := vpMiddle;
    FPlayerGroup.InsertFront(Row);

    for j := 0 to MaxSlotsPerRow - 1 do
    begin
      InRow := i * MaxSlotsPerRow + j;
      if InRow >= TotalPlayers then Break;

      FCheckSlots[InRow].PlayerId := Payload.Players[InRow].PlayerId;
      Slot := TCastleDesign.Create(Self);
      FCheckSlots[InRow].Design := Slot;
      if Payload.Players[InRow].Ready then
        Slot.Url := 'castle-data:/user_interfaces/Player1ReadyDesign.castle-user-interface'
      else
        Slot.Url := 'castle-data:/user_interfaces/Player2WaitingDesign.castle-user-interface';
      Slot.Width := 72;
      Slot.Height := 104;
      Slot.VerticalAnchorParent := vpMiddle;
      Slot.VerticalAnchorSelf := vpMiddle;
      Row.InsertFront(Slot);
    end;
  end;
  Payload.Free;

  if FCheckPanelBg <> nil then
    FCheckPanelBg.Height := 40 + RowCount * 114;
end;

procedure TViewLobby.ClearCheckSlots;
begin
  FCheckSlots := nil;
  if FPlayerGroup <> nil then
    while FPlayerGroup.ControlsCount > 0 do
      FPlayerGroup.Controls[0].Free;
end;

procedure TViewLobby.OnReadyBtn(const Sender: TCastleUserInterface;
  const Event: TInputPressRelease; var Handled: Boolean);
begin
  if FLobbyClient <> nil then
  begin
    WriteLn(StdErr, '[Client] Player confirmed ready');
    FLobbyClient.MatchmakingSystem.SendReadyCheck;
    ReadyDesign.Exists := False;
    if CheckReadingPlayersDesign <> nil then
      CheckReadingPlayersDesign.Exists := True;
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

procedure TViewLobby.OnStartGame(const Event: TClientGameEvent);
var
  Port: Word;
  Token: string;
begin
  Port := Round(Event.Amount);
  Token := '';
  if FLobbyClient <> nil then
  begin
    Token := FLobbyClient.NetSystem.AuthToken;
    FLobbyClient.NetSystem.Disconnect;
  end;
  WriteLn(StdErr, '[Client] Starting game on port ', Port, ' token="', Token, '"');
  ViewMain.StartGame('127.0.0.1', Port, Token);
  Container.View := ViewMain;
end;

end.
