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
    Pricel: TCastleDesign;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
    function Press(const Event: TInputPressRelease): Boolean; override;
    procedure StartGame(const AHost: string; APort: Word; ALobbyId: UInt32; const AToken: string = '');
  private
    FGameClient: TGameWorldClient;
    FGameHost: string;
    FGamePort: Word;
    FGameLobbyId: UInt32;
    FGameToken: string;
    FOverlay: TCastleRectangleControl;
    FAnimManager: TAnimationManager;
    FSceneRevealed: Boolean;
    procedure OnGameStateChanged(const Event: TClientGameEvent);
  end;

var
  ViewMain: TViewMain;

implementation

uses SysUtils;

constructor TViewMain.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/gameviewmain.castle-user-interface';
  // var
  //   BarTop: TCastleRectangleControl;
  // begin
  //   BarTop := Pricel.DesignedComponent('BarTop') as TCastleRectangleControl;
  //   BarTop.Translation.Y := -(Gap + BarTop.Height);
  // end;
end;

procedure TViewMain.StartGame(const AHost: string; APort: Word; ALobbyId: UInt32; const AToken: string);
begin
  FGameHost := AHost;
  FGamePort := APort;
  FGameLobbyId := ALobbyId;
  FGameToken := AToken;
end;

procedure TViewMain.Start;
var
  Factory: IEntityFactory;
begin
  inherited;

  FSceneRevealed := False;
  FAnimManager := TAnimationManager.Create;
  FOverlay := TCastleRectangleControl.Create(nil);
  FOverlay.FullSize := True;
  FOverlay.Color := Vector4(0, 0, 0, 1);
  FOverlay.Exists := True;
  InsertFront(FOverlay);

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
  FGameClient.ViewSystem.View := Self;
  FGameClient.NetSystem.AuthToken := FGameToken;
  FGameClient.NetSystem.Connect(FGameHost, FGamePort, FGameClient.LobbyId);
end;

procedure TViewMain.Stop;
begin
  GlobalClientEventBus.Unsubscribe(@OnGameStateChanged);
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
  FA: TFadeAnimation;
begin
  WritelnLog('Client', 'Game state: %d', [Round(Event.Amount)]);
  if FSceneRevealed then Exit;
  if TServerGameState(Round(Event.Amount)) <> sgsPlaying then Exit;
  FSceneRevealed := True;
  FA := TFadeAnimation.Create(FOverlay, 0.8, 1, 0);
  FAnimManager.Add(FA);
  FA.Start;
end;

end.
