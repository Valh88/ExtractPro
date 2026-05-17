unit GameWorldClient;

interface

uses
  GameWorld, ShotSystem, WorldBridge, CastleTransform, help_types, CastleKeysMouse, Interfaces;

type
  TGameWorldClient = class(TGameWorld)
  protected
    FMainPlayerId: TEntityId;
    procedure RegisterSystems; override;
  public
    constructor Create(const ARoot: TCastleAbstractRootTransform;
      const AFactory: IEntityFactory);
    property MainPlayerId: TEntityId read FMainPlayerId write FMainPlayerId;
  end;

implementation

{ TGameWorldClient }

constructor TGameWorldClient.Create(const ARoot: TCastleAbstractRootTransform;
  const AFactory: IEntityFactory);
var
  B: TWorldBridge;
begin
  B := TWorldBridge.Create(ARoot);
  inherited Create(B as IGameWorld, AFactory);
  B.GameLogic := Self;
end;

procedure TGameWorldClient.RegisterSystems;
begin
  inherited;
  FSystems.Add(TShotSystem.Create(Self));
end;

end.
