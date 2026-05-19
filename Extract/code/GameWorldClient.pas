unit GameWorldClient;

interface

uses
  GameWorld, ShotSystem, WorldBridge, CastleTransform, CastleViewport,
  help_types, CastleKeysMouse, Interfaces, ClientNetSystem;

type
  TGameWorldClient = class(TGameWorld)
  protected
    FMainPlayerId: TEntityId;
    FViewport: TCastleViewport;
    procedure RegisterSystems; override;
  public
    constructor Create(const ARoot: TCastleAbstractRootTransform;
      const AFactory: IEntityFactory; const AViewport: TCastleViewport);
    property MainPlayerId: TEntityId read FMainPlayerId write FMainPlayerId;
    property Viewport: TCastleViewport read FViewport write FViewport;
  end;

implementation

{ TGameWorldClient }

constructor TGameWorldClient.Create(const ARoot: TCastleAbstractRootTransform;
  const AFactory: IEntityFactory; const AViewport: TCastleViewport);
var
  B: TWorldBridge;
begin
  B := TWorldBridge.Create(ARoot);
  inherited Create(B as IGameWorld, AFactory);
  B.GameLogic := Self;
  FViewport := AViewport;
end;

procedure TGameWorldClient.RegisterSystems;
begin
  inherited;
  AddSystem(TShotSystem.Create(Self));
  AddSystem(TClientNetSystem.Create(Self));
end;

end.
