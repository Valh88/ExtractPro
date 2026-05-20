unit GameViewMain;

interface

uses Classes,
  CastleVectors, CastleComponentSerialize, CastleViewport, CastleTransform,
  CastleUIControls, CastleControls, CastleKeysMouse,
  help_types, Interfaces, WorldBridge, EntityManager, GameWorldClient;

type
  TViewMain = class(TCastleView)
  published
    LabelFps: TCastleLabel;
    Viewport1: TCastleViewport;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
    function Press(const Event: TInputPressRelease): Boolean; override;
  private
    FGameClient: TGameWorldClient;
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

procedure TViewMain.Start;
var
  Factory: IEntityFactory;
begin
  inherited;
  Factory := TEntityManager.Create(
    'castle-data:/PlayerProto.castle-transform',
    'castle-data:/EnemyProto.castle-transform',
    Viewport1
  );
  FGameClient := TGameWorldClient.Create(Viewport1.Items, Factory, Viewport1);
  FGameClient.Start;
  //FGameClient.SpawnMainPlayer;
end;

procedure TViewMain.Stop;
begin
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
end;

function TViewMain.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited;
  if FGameClient <> nil then
    FGameClient.Press(Event);
end;

end.
