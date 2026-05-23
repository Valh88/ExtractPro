unit GameWorldServer;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  GameWorld, WorldBridge, CastleTransform, Interfaces, ServerNetSystem, RNL, NetMessages,
  ServerSnapshotSystem, ServerShotSystem;

type
  TGameWorldServer = class(TGameWorld)
  protected
    FPort: Word;
    FMaxPlayers: Integer;
    FNetSystem: TServerNetSystem;
    FShotSystem: TServerShotSystem;
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
  FShotSystem := TServerShotSystem.Create(Self);
  FNetSystem.ShotSystem := FShotSystem;
  FShotSystem.SendHitProc := procedure(const APlayerId: UInt32; const HitData: THitData)
  var
    M: TNetMessage;
  begin
    M.Init(msgHit, HitData.ToBytes);
    FNetSystem.Broadcast(M);
  end;
  AddSystem(FNetSystem);
  AddSystem(TServerSnapshotSystem.Create(Self, FNetSystem.Server));
  AddSystem(FShotSystem);
end;

end.
