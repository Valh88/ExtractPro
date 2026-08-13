unit GameViewMain;

interface

uses Classes,
  CastleVectors, CastleComponentSerialize, CastleViewport, CastleTransform,
  CastleUIControls, CastleControls, CastleKeysMouse, CastleLog,
  help_types, Interfaces, WorldBridge, EntityManager, GameWorldClient,
  GameViewSystem, ClientEventBus, GameSettings,
  UiAnimation, AnimationManager;

type
  TViewMain = class(TCastleView)
  published
    Viewport1: TCastleViewport;
    InfoDesign: TCastleDesign;
    TimerSceneStartDesign: TCastleDesign;
    ExtractTimerDesign: TCastleDesign;
    GameMenuDesign: TCastleDesign;
    Hud: TCastleDesign;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
    function Press(const Event: TInputPressRelease): Boolean; override;
    procedure StartGame(const AHost: string; APort: Word; ALobbyId: UInt32;
      APlayerId: UInt32; const AToken: string = '');
    procedure ShowInfo(const ATitle, AText: String);
    procedure HideInfo;
  private
    FGameClient: TGameWorldClient;
    FGameHost: string;
    FGamePort: Word;
    FGameLobbyId: UInt32;
    FGamePlayerId: UInt32;
    FGameToken: string;
    FFpsValue: TCastleLabel;
    FPingValue: TCastleLabel;
    FOverlay: TCastleRectangleControl;
    FAnimManager: TAnimationManager;
    FSceneRevealed: Boolean;
    FDotsAnim: TDotsAnimation;
    FFadeAnim: TDesignFadeAnimation;
    FCountdownLeft: Single;
    FLastShownCountdown: Integer;
    FCountdownAnim: TCountdownPulseAnimation;
    FMenuHomeX: Single;
    procedure OnGameStateChanged(const Event: TClientGameEvent);
    procedure OnPingUpdate(const Event: TClientGameEvent);
    procedure OnFadeOutComplete(Sender: TObject);
    procedure OnCountdownAnimComplete(Sender: TObject);
    procedure SetCountdownDigit(const AValue: Integer);
    procedure SetMenuOpen(const Open: Boolean);
    procedure OnMenuSlideOutComplete(Sender: TObject);
    procedure OnMenuPlayBtn(const Sender: TCastleUserInterface;
      const Event: TInputPressRelease; var Handled: Boolean);
  end;

var
  ViewMain: TViewMain;

implementation

uses SysUtils, Math;

const
  MenuDimDuration = 0.3;
  OverlayMenuAlpha = 0.5;
  MenuDimTag = 1;
  MenuSlideTag = 2;

constructor TViewMain.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/gameviewmain.castle-user-interface';
end;

procedure TViewMain.StartGame(const AHost: string; APort: Word; ALobbyId: UInt32;
  APlayerId: UInt32; const AToken: string);
begin
  FGameHost := AHost;
  FGamePort := APort;
  FGameLobbyId := ALobbyId;
  FGamePlayerId := APlayerId;
  FGameToken := AToken;
end;

procedure TViewMain.Start;
var
  Factory: IEntityFactory;
  VS: TGameViewSystem;
begin
  inherited;

  FSceneRevealed := False;
  FMenuHomeX := GameMenuDesign.Translation.X;
  FAnimManager := TAnimationManager.Create;
  FDotsAnim := TDotsAnimation.Create(nil, '', 0.5);
  FAnimManager.Add(FDotsAnim);
  FOverlay := TCastleRectangleControl.Create(nil);
  FOverlay.FullSize := True;
  FOverlay.Color := Vector4(0, 0, 0, 1);
  FOverlay.Exists := True;
  InsertFront(FOverlay);
  InfoDesign.Parent.RemoveControl(InfoDesign);
  InsertFront(InfoDesign);

  GlobalClientEventBus.Subscribe(cgeGameStateChanged, @OnGameStateChanged);
  GlobalClientEventBus.Subscribe(cgePingUpdate, @OnPingUpdate);

  if Hud <> nil then
  begin
    FFpsValue := (Hud.DesignedComponent('StatisticDesign') as TCastleDesign)
      .DesignedComponent('FpsValue') as TCastleLabel;
    FPingValue := (Hud.DesignedComponent('StatisticDesign') as TCastleDesign)
      .DesignedComponent('PingValue') as TCastleLabel;
  end;

  Factory := TEntityManager.Create(
    'castle-data:/PlayerProto.castle-transform',
    'castle-data:/models/prototype/JulietTransformDesign.castle-transform',
    'castle-data:/EnemyProto.castle-transform',
    Viewport1
  );
  FGameClient := TGameWorldClient.Create(Viewport1.Items, Factory, Viewport1);
  FGameClient.Start;
  FGameClient.LobbyId := FGameLobbyId;
  VS := FGameClient.ViewSystem;
  VS.View := Self;
  FGameClient.NetSystem.AuthToken := FGameToken;
  FGameClient.NetSystem.LobbyPlayerId := FGamePlayerId;
  FGameClient.NetSystem.Connect(FGameHost, FGamePort, FGameClient.LobbyId);

  (GameMenuDesign.DesignedComponent('BtnPlay') as TCastleButton).OnPress := @OnMenuPlayBtn;
end;

procedure TViewMain.Stop;
begin
  GlobalClientEventBus.Unsubscribe(@OnGameStateChanged);
  GlobalClientEventBus.Unsubscribe(@OnPingUpdate);
  FDotsAnim.Stop;
  if FFadeAnim <> nil then
    FFadeAnim.Stop;
  FreeAndNil(FAnimManager);
  FDotsAnim := nil;
  FFadeAnim := nil;
  FCountdownAnim := nil;
  FreeAndNil(FOverlay);
  Viewport1.Camera := nil;
  FGameClient.Free;
  inherited;
end;

procedure TViewMain.Update(const SecondsPassed: Single; var HandleInput: Boolean);
begin
  inherited;
  if FFpsValue <> nil then
    FFpsValue.Caption := IntToStr(Round(Container.Fps.RealFps));
  if FGameClient <> nil then
    FGameClient.Update(SecondsPassed);
  if FAnimManager <> nil then
    FAnimManager.Update(SecondsPassed);
  if FCountdownLeft > 0 then
  begin
    FCountdownLeft := FCountdownLeft - SecondsPassed;
    if FCountdownLeft < 0 then
      FCountdownLeft := 0;
    if FLastShownCountdown <> Ceil(FCountdownLeft) then
    begin
      FLastShownCountdown := Ceil(FCountdownLeft);
      if FLastShownCountdown > 0 then
        SetCountdownDigit(FLastShownCountdown)
      else if TimerSceneStartDesign <> nil then
        TimerSceneStartDesign.Exists := False;
    end;
  end;
end;

function TViewMain.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited;
  if Event.Key = keyEscape then
  begin
    if FGameClient <> nil then
      if GameMenuDesign.Exists then
        SetMenuOpen(False)
      else if FCountdownLeft <= 0 then
        SetMenuOpen(True);
    Exit(True);
  end;
  if FGameClient <> nil then
    FGameClient.Press(Event);
end;

procedure TViewMain.SetMenuOpen(const Open: Boolean);
var
  FA: TFadeAnimation;
  SA: TSlideAnimation;
  SlideOffset: Single;
begin
  FAnimManager.Cancel(MenuDimTag);
  FAnimManager.Cancel(MenuSlideTag);
  SlideOffset := GameMenuDesign.Width + 100;
  if Open then
  begin
    GameMenuDesign.Parent.RemoveControl(GameMenuDesign);
    InsertFront(GameMenuDesign);
    GameMenuDesign.Exists := True;
    SA := TSlideAnimation.Create(GameMenuDesign, MenuDimDuration,
      FMenuHomeX + SlideOffset, FMenuHomeX, True);
    FA := TFadeAnimation.Create(FOverlay, MenuDimDuration, 0, OverlayMenuAlpha);
  end else
  begin
    SA := TSlideAnimation.Create(GameMenuDesign, MenuDimDuration,
      GameMenuDesign.Translation.X, FMenuHomeX + SlideOffset, False);
    SA.OnComplete := @OnMenuSlideOutComplete;
    FA := TFadeAnimation.Create(FOverlay, MenuDimDuration, OverlayMenuAlpha, 0);
  end;
  SA.Tag := MenuSlideTag;
  FAnimManager.Add(SA);
  SA.Start;
  FA.Tag := MenuDimTag;
  FAnimManager.Add(FA);
  FA.Start;
  if Open then
    FGameClient.Fsm.ChangeState(cgsMainMenu)
  else
    FGameClient.Fsm.ChangeState(cgsPlaying);
end;

procedure TViewMain.OnMenuSlideOutComplete(Sender: TObject);
begin
  GameMenuDesign.Exists := False;
end;

procedure TViewMain.OnMenuPlayBtn(const Sender: TCastleUserInterface;
  const Event: TInputPressRelease; var Handled: Boolean);
begin
  SetMenuOpen(False);
end;

procedure TViewMain.OnGameStateChanged(const Event: TClientGameEvent);
var
  State: TServerGameState;
  FA: TFadeAnimation;
begin
  State := TServerGameState(Round(Event.Amount));
  WritelnLog('Client', 'Game state: %d', [Ord(State)]);

  case State of
    sgsStart:
      ShowInfo('', 'Загрузка');
    sgsLoading:
      ShowInfo('', 'Загрузка мира');
    sgsWaitingPlayers:
      ShowInfo('', 'Ожидание игроков');
    sgsCountdown:
    begin
      FCountdownLeft := GameStartCountdownSeconds;
      FLastShownCountdown := 0;
      if FFadeAnim <> nil then
      begin
        FAnimManager.Remove(FFadeAnim);
        FreeAndNil(FFadeAnim);
      end;
      if InfoDesign <> nil then
        InfoDesign.Exists := False;
      if TimerSceneStartDesign <> nil then
      begin
        TimerSceneStartDesign.Exists := True;
        SetCountdownDigit(Round(GameStartCountdownSeconds));
      end;
      if not FSceneRevealed then
      begin
        FSceneRevealed := True;
        FA := TFadeAnimation.Create(FOverlay, 0.8, 1, 0);
        FAnimManager.Add(FA);
        FA.Start;
      end;
      if FGameClient <> nil then
        FGameClient.InputEnabled := False;
    end;
    sgsPlaying:
    begin
      FCountdownLeft := 0;
      if TimerSceneStartDesign <> nil then
        TimerSceneStartDesign.Exists := False;
      if FCountdownAnim <> nil then
      begin
        FCountdownAnim.Stop;
        FCountdownAnim := nil;
      end;
      HideInfo;
      if FGameClient <> nil then
      begin
        FGameClient.Fsm.ChangeState(cgsPlaying);
        FGameClient.InputEnabled := True;
      end;
    end;
  end;
end;

procedure TViewMain.OnPingUpdate(const Event: TClientGameEvent);
begin
  if FPingValue <> nil then
    FPingValue.Caption := Format('%.0f', [Event.Amount]);
end;

procedure TViewMain.ShowInfo(const ATitle, AText: String);
var
  Title, Txt: TCastleLabel;
begin
  if InfoDesign = nil then Exit;
  if FFadeAnim <> nil then
  begin
    FAnimManager.Remove(FFadeAnim);
    FreeAndNil(FFadeAnim);
  end;
  Title := InfoDesign.DesignedComponent('InfoTitle') as TCastleLabel;
  Txt := InfoDesign.DesignedComponent('InfoText') as TCastleLabel;
  Title.Caption := ATitle;
  InfoDesign.Exists := True;
  FDotsAnim.Reset(Txt, AText);
end;

procedure TViewMain.HideInfo;
begin
  if InfoDesign = nil then Exit;
  if FFadeAnim <> nil then
  begin
    FAnimManager.Remove(FFadeAnim);
    FreeAndNil(FFadeAnim);
  end;
  FFadeAnim := TDesignFadeAnimation.Create(InfoDesign, 0.4, 1, 0);
  FFadeAnim.OnComplete := @OnFadeOutComplete;
  FAnimManager.Add(FFadeAnim);
  FFadeAnim.Start;
end;

procedure TViewMain.OnFadeOutComplete(Sender: TObject);
begin
  FFadeAnim := nil;
  if InfoDesign <> nil then
    InfoDesign.Exists := False;
end;

procedure TViewMain.SetCountdownDigit(const AValue: Integer);
var
  Lbl: TCastleLabel;
begin
  if TimerSceneStartDesign = nil then Exit;
  Lbl := TimerSceneStartDesign.DesignedComponent('TimerLabel') as TCastleLabel;
  if Lbl <> nil then
  begin
    Lbl.Caption := IntToStr(AValue);
    if FCountdownAnim <> nil then
    begin
      FAnimManager.Remove(FCountdownAnim);
      FreeAndNil(FCountdownAnim);
    end;
    FCountdownAnim := TCountdownPulseAnimation.Create(Lbl, 1.0);
    FCountdownAnim.OnComplete := @OnCountdownAnimComplete;
    FAnimManager.Add(FCountdownAnim);
    FCountdownAnim.Start;
  end;
end;

procedure TViewMain.OnCountdownAnimComplete(Sender: TObject);
begin
  FCountdownAnim := nil;
end;

end.
