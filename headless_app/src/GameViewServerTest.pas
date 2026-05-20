unit GameViewServerTest;

{$mode objfpc}{$H+}
{$modeswitch functionreferences}

interface

uses Classes,
  CastleVectors, CastleComponentSerialize, CastleViewport, CastleTransform,
  CastleUIControls, CastleControls, CastleKeysMouse,
  help_types, Interfaces, WorldBridge,
  ServerEntityFactory, GameWorldServer, ServerNetSystem;

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
    FGameServer: TGameWorldServer;
    procedure OnServerLog(Sender: TObject; const Msg: String);
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
  FGameServer := TGameWorldServer.Create(Viewport1.Items, Factory, 7777, 8);
  FGameServer.Start;
  FGameServer.NetSystem.OnLog := @OnServerLog;
  FGameServer.NetSystem.StartServer;

  LabelStatus.Caption := 'Server: starting on port 7777...';
end;

procedure TViewServerTest.OnServerLog(Sender: TObject; const Msg: String);
begin
  LabelStatus.Caption := Msg;
end;

procedure TViewServerTest.Stop;
begin
  FGameServer.Free;
  Viewport1.Camera := nil;
  inherited;
end;

procedure TViewServerTest.Update(const SecondsPassed: Single; var HandleInput: Boolean);
begin
  inherited;
  LabelFps.Caption := 'FPS: ' + Container.Fps.ToString;
  if FGameServer <> nil then
    FGameServer.Update(SecondsPassed);
end;

function TViewServerTest.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited;
  if FGameServer <> nil then
    FGameServer.Press(Event);
end;

end.
