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
      FPlayerGroup: TCastleHorizontalGroup;
      FCheckSlots: array of TCheckSlot;
    procedure OnMMState(const Event: TClientGameEvent);
    procedure OnReadyCheck(const Event: TClientGameEvent);
    procedure OnReadyCheckUpdate(const Event: TClientGameEvent);
    procedure OnReadyBtn(const Sender: TCastleUserInterface;
      const Event: TInputPressRelease; var Handled: Boolean);
    procedure OnCancelBtn(const Sender: TCastleUserInterface;
      const Event: TInputPressRelease; var Handled: Boolean);
    procedure ClearCheckSlots;
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

    if CheckReadingPlayersDesign <> nil then
      FPlayerGroup := CheckReadingPlayersDesign.DesignedComponent('PlayerGroup') as TCastleHorizontalGroup;

    GlobalClientEventBus.Subscribe(cgeMatchmakingStateChanged, @OnMMState);
    GlobalClientEventBus.Subscribe(cgeReadyCheck, @OnReadyCheck);
    GlobalClientEventBus.Subscribe(cgeReadyCheckUpdate, @OnReadyCheckUpdate);

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
  ReadyDesign.Exists := (Event.Amount > 0.5) and (Event.Amount < 1.5);
  if CheckReadingPlayersDesign <> nil then
  begin
    CheckReadingPlayersDesign.Exists := (Event.Amount > 0.5) and (Event.Amount < 1.5);
    if not CheckReadingPlayersDesign.Exists then
      ClearCheckSlots;
  end;
end;

procedure TViewLobby.OnReadyCheckUpdate(const Event: TClientGameEvent);
var
  Payload: TReadyCheckUpdatePayload;
  i: Integer;
  Slot: TCastleDesign;
begin
  Payload := TReadyCheckUpdatePayload(Event.Data);
  if Payload = nil then Exit;

  ClearCheckSlots;
  if FPlayerGroup = nil then
  begin
    Payload.Free;
    Exit;
  end;

  SetLength(FCheckSlots, Length(Payload.Players));
  for i := 0 to High(Payload.Players) do
  begin
    FCheckSlots[i].PlayerId := Payload.Players[i].PlayerId;
    Slot := TCastleDesign.Create(Self);
    FCheckSlots[i].Design := Slot;
    if Payload.Players[i].Ready then
      Slot.Url := 'castle-data:/user_interfaces/Player1ReadyDesign.castle-user-interface'
    else
      Slot.Url := 'castle-data:/user_interfaces/Player2WaitingDesign.castle-user-interface';
    Slot.Width := 72;
    Slot.Height := 104;
    Slot.VerticalAnchorParent := vpMiddle;
    Slot.VerticalAnchorSelf := vpMiddle;
    FPlayerGroup.InsertFront(Slot);
  end;
  Payload.Free;
end;

procedure TViewLobby.ClearCheckSlots;
var
  i: Integer;
  D: TCastleDesign;
begin
  for i := 0 to High(FCheckSlots) do
  begin
    D := FCheckSlots[i].Design;
    if D <> nil then
    begin
      if D.Parent <> nil then
        D.Parent.RemoveControl(D);
      D.Free;
    end;
  end;
  FCheckSlots := nil;
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
