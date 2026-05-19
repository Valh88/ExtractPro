unit GameWorldServer;

interface

uses
  GameWorld, WorldBridge, CastleTransform, Interfaces, ServerNetSystem, RNL, NetMessages;

type
  TGameWorldServer = class(TGameWorld)
  protected
    FPort: Word;
    FMaxPlayers: Integer;
    FNetSystem: TServerNetSystem;
    procedure RegisterSystems; override;
  public
    constructor Create(const ARoot: TCastleAbstractRootTransform;
      const AFactory: IEntityFactory; const APort: Word = 7777;
      const AMaxPlayers: Integer = 8);
    property NetSystem: TServerNetSystem read FNetSystem;
  end;

implementation

{ TGameWorldServer }

constructor TGameWorldServer.Create(const ARoot: TCastleAbstractRootTransform;
  const AFactory: IEntityFactory; const APort: Word;
  const AMaxPlayers: Integer);
var
  B: TWorldBridge;
begin
  FPort := APort;
  FMaxPlayers := AMaxPlayers;
  B := TWorldBridge.Create(ARoot);
  inherited Create(B as IGameWorld, AFactory);
  B.GameLogic := Self;
end;

procedure TGameWorldServer.RegisterSystems;
begin
  inherited;
  FNetSystem := TServerNetSystem.Create(Self, FPort, FMaxPlayers);
  AddSystem(FNetSystem);
end;

end.
