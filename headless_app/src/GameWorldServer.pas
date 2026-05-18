unit GameWorldServer;

interface

uses
  GameWorld, WorldBridge, CastleTransform, Interfaces, ServerNetSystem, RNL, NetMessages;

type
  TGameWorldServer = class(TGameWorld)
  protected
    FPort: Word;
    FMaxPlayers: Integer;
    procedure RegisterSystems; override;
  public
    constructor Create(const ARoot: TCastleAbstractRootTransform;
      const AFactory: IEntityFactory; const APort: Word = 7777;
      const AMaxPlayers: Integer = 8);
    function NetSystem: TServerNetSystem;
    procedure OnPlayerConnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
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

  NetSystem.OnConnect := @OnPlayerConnected;
end;

procedure TGameWorldServer.RegisterSystems;
begin
  inherited;
  FSystems.Add(TServerNetSystem.Create(Self, FPort, FMaxPlayers));
end;

function TGameWorldServer.NetSystem: TServerNetSystem;
var
  i: Integer;
begin
  for i := 0 to FSystems.Count - 1 do
    if FSystems[i] is TServerNetSystem then
      Exit(TServerNetSystem(FSystems[i]));
  Result := nil;
end;

procedure TGameWorldServer.OnPlayerConnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
begin
  WriteLn('Player connected: ', PlayerId);
end;

end.
