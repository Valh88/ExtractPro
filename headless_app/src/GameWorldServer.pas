unit GameWorldServer;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

  uses
    GameWorld, WorldBridge, CastleTransform, Interfaces, ServerNetSystem, RNL, NetMessages,
    ServerSnapshotSystem, ServerShotSystem, ServerDbSystem,
    JobQueueSystem;

type
  TGameWorldServer = class(TGameWorld)
  protected
    FWorldRoot: TCastleAbstractRootTransform;
    FPort: Word;
    FMaxPlayers: Integer;
    FNetSystem: TServerNetSystem;
    FShotSystem: TServerShotSystem;
    FDbSystem: TServerDbSystem;
    procedure RegisterSystems; override;
  public
    procedure Update(const SecondsPassed: Single); override;
    constructor Create(const ARoot: TCastleAbstractRootTransform;
      const AFactory: IEntityFactory; const APort: Word = 7777;
      const AMaxPlayers: Integer = 8);
    destructor Destroy; override;
    procedure SetDbSystem(aDbSystem: TServerDbSystem);
    property NetSystem: TServerNetSystem read FNetSystem;
    property DbSystem: TServerDbSystem read FDbSystem;
  end;

implementation

{ TGameWorldServer }

constructor TGameWorldServer.Create(const ARoot: TCastleAbstractRootTransform;
  const AFactory: IEntityFactory; const APort: Word;
  const AMaxPlayers: Integer);
var
  B: TWorldBridge;
begin
  FWorldRoot := ARoot;
  FPort := APort;
  FMaxPlayers := AMaxPlayers;
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
  AddSystem(TJobQueueSystem.Create(Self));
end;

procedure TGameWorldServer.Update(const SecondsPassed: Single);
begin
  inherited Update(SecondsPassed);
  {$ifndef VISUAL}
  FWorldRoot.UpdateIncreaseTime(SecondsPassed);
  {$endif}
end;

end.