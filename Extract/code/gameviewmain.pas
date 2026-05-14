unit GameViewMain;

interface

uses Classes,
  CastleVectors, CastleComponentSerialize, CastleViewport, CastleTransform,
  CastleUIControls, CastleControls, CastleKeysMouse,
  help_types, Interfaces, WorldBridge, EntityManager,
  MouseLookOverlay;

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
    FWorldBridge: IGameWorld;
    FMouseLookUi: TMouseLookOverlay;
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
  Entity: IGameEntity;
begin
  inherited;
  Factory := TEntityManager.Create(
    'castle-data:/PlayerProto.castle-transform',
    'castle-data:/EnemyProto.castle-transform',
    Viewport1
  );
  FWorldBridge := TWorldBridge.Create(Viewport1.Items, Factory);
  FWorldBridge.Start;
  Entity := Factory.CreateMainPlayerEntity(42);
  FWorldBridge.RegisterEntity(Entity);

  FMouseLookUi := TMouseLookOverlay.Create(Self);
  FMouseLookUi.FullSize := true;
  FMouseLookUi.Viewport := Viewport1;
  FMouseLookUi.Hero := Entity.Transform;
  InsertBack(FMouseLookUi);
  Entity := Factory.CreatePlayerEntity(43);
  FWorldBridge.RegisterEntity(Entity);
end;

procedure TViewMain.Stop;
begin
  Viewport1.Camera := nil;
  FWorldBridge := nil;
  inherited;
end;

procedure TViewMain.Update(const SecondsPassed: Single; var HandleInput: Boolean);
begin
  inherited;
  LabelFps.Caption := 'FPS: ' + Container.Fps.ToString;
  if FWorldBridge <> nil then
    FWorldBridge.Update(SecondsPassed);
end;

function TViewMain.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited;
  FWorldBridge.Press(Event);
end;

end.
