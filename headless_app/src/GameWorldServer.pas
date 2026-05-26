unit GameWorldServer;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  GameWorld, WorldBridge, CastleTransform, Interfaces, ServerNetSystem, RNL, NetMessages,
  ServerSnapshotSystem, ServerShotSystem, ServerAuthSystem, ServerDbSystem, AuthTypes;

type
  TGameWorldServer = class(TGameWorld)
  protected
    FPort: Word;
    FMaxPlayers: Integer;
    FAuthPort: Word;
    FRequireAuth: Boolean;
    FNetSystem: TServerNetSystem;
    FShotSystem: TServerShotSystem;
    FAuthSystem: TServerAuthSystem;
    FDbSystem: TServerDbSystem;
    procedure RegisterSystems; override;
  public
    constructor Create(const ARoot: TCastleAbstractRootTransform;
      const AFactory: IEntityFactory; const APort: Word = 7777;
      const AMaxPlayers: Integer = 8; const AAuthPort: Word = 0;
      const ARequireAuth: Boolean = False);
    destructor Destroy; override;
    procedure SetDbSystem(aDbSystem: TServerDbSystem);
    property NetSystem: TServerNetSystem read FNetSystem;
    property AuthSystem: TServerAuthSystem read FAuthSystem;
    property DbSystem: TServerDbSystem read FDbSystem;
  end;

implementation

{ TGameWorldServer }

constructor TGameWorldServer.Create(const ARoot: TCastleAbstractRootTransform;
  const AFactory: IEntityFactory; const APort: Word;
  const AMaxPlayers: Integer; const AAuthPort: Word;
  const ARequireAuth: Boolean);
var
  B: TWorldBridge;
begin
  FPort := APort;
  FMaxPlayers := AMaxPlayers;
  FAuthPort := AAuthPort;
  FRequireAuth := ARequireAuth;
  B := TWorldBridge.Create(ARoot);
  inherited Create(B as IGameWorld, AFactory);
  B.GameLogic := Self;
end;

procedure TGameWorldServer.SetDbSystem(aDbSystem: TServerDbSystem);
begin
  FDbSystem := aDbSystem;
  if aDbSystem <> nil then
    AddSystem(aDbSystem);
end;

destructor TGameWorldServer.Destroy;
begin
  inherited;
end;

procedure TGameWorldServer.RegisterSystems;
begin
  inherited;
  if FAuthPort > 0 then
  begin
    FAuthSystem := TServerAuthSystem.Create(Self, FAuthPort);
    AddSystem(FAuthSystem);
  end;
  FNetSystem := TServerNetSystem.Create(Self, FPort, FMaxPlayers);
  FShotSystem := TServerShotSystem.Create(Self);
  FNetSystem.ShotSystem := FShotSystem;
  FNetSystem.RequireAuth := FRequireAuth;
  if FAuthSystem <> nil then
    FNetSystem.AuthValidator := FAuthSystem.Validator;
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