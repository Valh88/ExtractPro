unit GameWorldServer;

interface

uses
  GameWorld, WorldBridge, CastleTransform, Interfaces;

type
  TGameWorldServer = class(TGameWorld)
  protected
    procedure RegisterSystems; override;
  public
    constructor Create(const ARoot: TCastleAbstractRootTransform;
      const AFactory: IEntityFactory);
  end;

implementation

{ TGameWorldServer }

constructor TGameWorldServer.Create(const ARoot: TCastleAbstractRootTransform;
  const AFactory: IEntityFactory);
var
  B: TWorldBridge;
begin
  B := TWorldBridge.Create(ARoot);
  inherited Create(B as IGameWorld, AFactory);
  B.GameLogic := Self;
end;

procedure TGameWorldServer.RegisterSystems;
begin
  inherited;
end;

end.
