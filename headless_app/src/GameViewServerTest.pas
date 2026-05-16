{
  GameViewServerTest.pas — визуальный тест сервера ExtractPro.

  ┌─────────────────────────────────────────────────────────────────────┐
  │  Используется при сборке с -dVISUAL                                │
  │                                                              ���      │
  │  TCastleView, загружающий gameviewmain.castle-user-interface:      │
  │    - Viewport1 + физическая сцена (пол, коробки)                   │
  │    - LabelFps — счётчик FPS                                        │
  │    - LabelStatus — "Server: port 7777, players N"                  │
  │                                                                     │
  │  При старте:                                                        │
  │    1. Создаёт TServerEntityFactory (без камер/управлений)           │
  │    2. Создаёт TWorldBridge, регистрирует тестового игрока          │
  │    3. Создаёт TGameServer(7777, 8), подписывается на события       │
  │    4. Каждый кадр: FGameServer.Service(0) + WorldBridge.Update     │
  │                                                                     │
  │  События сервера:                                                   │
  │    OnServerConnect    → UpdateStatus (обновить LabelStatus)         │
  │    OnServerDisconnect → UpdateStatus                                │
  │    OnServerReceive    → заглушка (обработка пакетов)                │
  │                                                                     │
  │  Зависимости: CastleViewport, CastleControls, WorldBridge,          │
  │               GameWorld, NetServer, ServerEntityFactory             │
  └─────────────────────────────────────────────────────────────────────┘
}
unit GameViewServerTest;

interface

uses Classes,
  CastleVectors, CastleComponentSerialize, CastleViewport, CastleTransform,
  CastleUIControls, CastleControls, CastleKeysMouse,
  help_types, Interfaces, GameConfig,
  RNL, NetServer, NetMessages,
  ServerEntityFactory, GameWorldServer;

type
  TViewServerTest = class(TCastleView)
  published
    LabelFps: TCastleLabel;
    LabelStatus: TCastleLabel;
    Viewport1: TCastleViewport;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
    function Press(const Event: TInputPressRelease): Boolean; override;
  private
    FGameClient: TGameWorldServer;
    FGameServer: TGameServer;
    procedure OnServerConnect(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
    procedure OnServerDisconnect(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
    procedure OnServerReceive(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32; const Msg: TNetMessage);
    procedure UpdateStatus;
  end;

var
  ViewServerTest: TViewServerTest;

implementation

uses SysUtils;

constructor TViewServerTest.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/gameviewmain.castle-user-interface';
end;

procedure TViewServerTest.Start;
var
  Factory: IEntityFactory;
begin
  inherited;

  Factory := TServerEntityFactory.Create(
    'castle-data:/PlayerProto.castle-transform',
    ''
  );
  FGameClient := TGameWorldServer.Create(Viewport1.Items, Factory);
  FGameClient.Start;

  FGameServer := TGameServer.Create(7777, 8);
  FGameServer.OnConnect := @OnServerConnect;
  FGameServer.OnDisconnect := @OnServerDisconnect;
  FGameServer.OnReceive := @OnServerReceive;
  FGameServer.Start;
  LabelStatus.Caption := 'Server: starting on port 7777...';
end;

procedure TViewServerTest.Stop;
begin
  FGameServer.Free;
  FGameClient.Free;
  Viewport1.Camera := nil;
  inherited;
end;

procedure TViewServerTest.Update(const SecondsPassed: Single; var HandleInput: Boolean);
begin
  inherited;
  LabelFps.Caption := 'FPS: ' + Container.Fps.ToString;
  if FGameServer <> nil then
    FGameServer.Service(0);
  if FGameClient <> nil then
    FGameClient.Update(SecondsPassed);
end;

function TViewServerTest.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited;
  if FGameClient <> nil then
    FGameClient.Press(Event);
end;

procedure TViewServerTest.OnServerConnect(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
begin
  UpdateStatus;
end;

procedure TViewServerTest.OnServerDisconnect(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
begin
  UpdateStatus;
end;

procedure TViewServerTest.OnServerReceive(Sender: TObject; Peer: TRNLPeer;
  PlayerId: UInt32; const Msg: TNetMessage);
begin
  // обработка входящих пакетов от клиентов
end;

procedure TViewServerTest.UpdateStatus;
begin
  if FGameServer <> nil then
    LabelStatus.Caption := Format('Server: port %d, players %d',
      [FGameServer.Port, FGameServer.Peers]);
end;

end.
