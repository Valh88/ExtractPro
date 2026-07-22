unit GameWorldClient;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, GameWorld, ShotSystem, WorldBridge, CastleTransform, CastleViewport, CastleVectors,
  help_types, CastleKeysMouse, Interfaces, ClientNetSystem,
  MouseLookOverlay, FirstPersonCameraBehavior,
  ClientSnapshotSystem, ClientOutbox, NetMessages, ClientPlayerSyncBehavior,
  ClientAuthSystem, RpcClient, JobQueueSystem,
  GameViewSystem;

type
  TGameWorldClient = class(TGameWorld)
  protected
    FMainPlayerId: TEntityId;
    FViewport: TCastleViewport;
    FMouseLookUi: TMouseLookOverlay;
    FSnapSystem: TClientSnapshotSystem;
    FOutbox: TClientOutbox;
    FNetSystem: TClientNetSystem;
    FAuthSystem: TClientAuthSystem;
    FRpc: TRpcClient;
    FLobbyId: UInt32;
    FViewSystem: TGameViewSystem;
    procedure RegisterSystems; override;
  public
    constructor Create(const ARoot: TCastleAbstractRootTransform;
      const AFactory: IEntityFactory; const AViewport: TCastleViewport);
    destructor Destroy; override;
    procedure SpawnMainPlayer;
    procedure HandleJoinAccept(const AEntityId: TEntityId; const APosX, APosY, APosZ, ARotY: Single); override;
    procedure InitMainPlayerOverlay(const AHeroTransform: TCastleTransform);
    property MainPlayerId: TEntityId read FMainPlayerId write FMainPlayerId;
    property Viewport: TCastleViewport read FViewport write FViewport;
    property NetSystem: TClientNetSystem read FNetSystem;
    property AuthSystem: TClientAuthSystem read FAuthSystem;
    property Rpc: TRpcClient read FRpc;
    property LobbyId: UInt32 read FLobbyId write FLobbyId;
    property ViewSystem: TGameViewSystem read FViewSystem;
  end;

implementation

{ TGameWorldClient }

constructor TGameWorldClient.Create(const ARoot: TCastleAbstractRootTransform;
  const AFactory: IEntityFactory; const AViewport: TCastleViewport);
var
  B: TWorldBridge;
begin
  FRpc := TRpcClient.Create;
  B := TWorldBridge.Create(ARoot);
  inherited Create(B as IGameWorld, AFactory);
  B.GameLogic := Self;
  FViewport := AViewport;
  FMouseLookUi := nil;
  FLobbyId := 1;
end;

destructor TGameWorldClient.Destroy;
begin
  FreeAndNil(FMouseLookUi);
  FRpc.Free;
  inherited;
end;

procedure TGameWorldClient.InitMainPlayerOverlay(const AHeroTransform: TCastleTransform);
begin
  if FMouseLookUi <> nil then
    FreeAndNil(FMouseLookUi);
  FMouseLookUi := TMouseLookOverlay.Create(FViewport.Owner);
  FMouseLookUi.FullSize := true;
  FMouseLookUi.Viewport := FViewport;
  FMouseLookUi.Hero := AHeroTransform;
  FViewport.InsertBack(FMouseLookUi);
end;

procedure TGameWorldClient.SpawnMainPlayer;
var
  Entity: IGameEntity;
begin
  Entity := Factory.CreateMainPlayerEntity(AllocateEntityId);
  AddPlayer(Entity);
  FMainPlayerId := Entity.EntityId;
  InitMainPlayerOverlay(Entity.Transform);

  Entity := Factory.CreatePlayerEntity(AllocateEntityId);
  AddPlayer(Entity);
end;

procedure TGameWorldClient.HandleJoinAccept(const AEntityId: TEntityId; const APosX, APosY, APosZ, ARotY: Single);
var
  Entity: IGameEntity;
begin
  Entity := Factory.CreateMainPlayerEntity(AEntityId);
  Entity.Transform.Translation := CastleVectors.Vector3(APosX, APosY, APosZ);
  // Entity.Rotation := ARotY; вращать роот или визуал?
  AddPlayer(Entity);
  FMainPlayerId := Entity.EntityId;
  InitMainPlayerOverlay(Entity.Transform);
end;

procedure TGameWorldClient.RegisterSystems;
var
  ShotSys: TShotSystem;
begin
  inherited;

  FAuthSystem := TClientAuthSystem.Create;
  AddSystem(FAuthSystem);

  FOutbox := TClientOutbox.Create(Self);

  ShotSys := TShotSystem.Create(Self);
  ShotSys.Outbox := FOutbox;
  AddSystem(ShotSys);

  FNetSystem := TClientNetSystem.Create(Self);
  FSnapSystem := TClientSnapshotSystem.Create(Self);
  FNetSystem.SnapSystem := FSnapSystem;
  FNetSystem.Rpc := FRpc;
  FRpc.SendProc := procedure(const M: TNetMessage)
  begin
    FNetSystem.SendToChannel(M, NET_CH_RELIABLE);
  end;

  FAuthSystem.OnAuthResult := procedure(Sender: TObject; const Result: TAuthRequestResult)
  begin
    if Result.Success then
      FNetSystem.AuthToken := Result.Token;
  end;

  FOutbox.SendToProc := procedure(const M: TNetMessage; const AChannel: Integer)
  begin
    FNetSystem.SendToChannel(M, AChannel);
  end;

  FNetSystem.DefaultSendProc := procedure(const M: TNetMessage; const AChannel: Integer)
  begin
    FOutbox.Add(M, AChannel);
  end;

  AddSystem(FNetSystem);
  AddSystem(FSnapSystem);
  AddSystem(FOutbox);
  AddSystem(TJobQueueSystem.Create(Self));
  FViewSystem := TGameViewSystem.Create(nil);
  AddSystem(FViewSystem);
end;

end.
