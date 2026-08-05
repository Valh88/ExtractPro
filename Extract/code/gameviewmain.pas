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
    LabelFps: TCastleLabel;
    Viewport1: TCastleViewport;
    InfoDesign: TCastleDesign;
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
    FOverlay: TCastleRectangleControl;
    FAnimManager: TAnimationManager;
    FSceneRevealed: Boolean;
    FDotsAnim: TDotsAnimation;
    FFadeAnim: TDesignFadeAnimation;
    procedure OnGameStateChanged(const Event: TClientGameEvent);
    procedure OnFadeOutComplete(Sender: TObject);
  end;

var
  ViewMain: TViewMain;

implementation

uses SysUtils;

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

  Factory := TEntityManager.Create(
    'castle-data:/PlayerProto.castle-transform',
    'castle-data:/PlayerProtoNoCamera.castle-transform',
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
end;

procedure TViewMain.Stop;
begin
  GlobalClientEventBus.Unsubscribe(@OnGameStateChanged);
  FDotsAnim.Stop;
  if FFadeAnim <> nil then
    FreeAndNil(FFadeAnim);
  FreeAndNil(FDotsAnim);
  FreeAndNil(FAnimManager);
  FreeAndNil(FOverlay);
  Viewport1.Camera := nil;
  FGameClient.Free;
  inherited;
end;

procedure TViewMain.Update(const SecondsPassed: Single; var HandleInput: Boolean);
begin
  inherited;
  LabelFps.Caption := 'FPS: ' + Container.Fps.ToString;
  if FGameClient <> nil then
    FGameClient.Update(SecondsPassed);
  if FAnimManager <> nil then
    FAnimManager.Update(SecondsPassed);
end;

function TViewMain.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited;
  if FGameClient <> nil then
    FGameClient.Press(Event);
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
    sgsPlaying:
    begin
      HideInfo;
      if not FSceneRevealed then
      begin
        FSceneRevealed := True;
        FA := TFadeAnimation.Create(FOverlay, 0.8, 1, 0);
        FAnimManager.Add(FA);
        FA.Start;
      end;
    end;
  end;
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
  FDotsAnim.Stop;
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

end.
