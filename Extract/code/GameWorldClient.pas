unit GameWorldClient;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, GameWorld, ShotSystem, WorldBridge, CastleTransform, CastleViewport, CastleVectors,
  help_types, CastleKeysMouse, Interfaces, ClientNetSystem,
  MouseLookOverlay, FirstPersonCameraBehavior, CharacterControllerBehavior,
  ClientSnapshotSystem, ClientOutbox, NetMessages, ClientPlayerSyncBehavior,
  ClientAuthSystem, RpcClient, JobQueueSystem,
  GameViewSystem, GameSettings, State, StateMachine;

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
    FSettings: TGameSettings;
    FFsm: TClientGameFsm;
    FInputEnabled: Boolean;
    FMainPlayerTransform: TCastleTransform;
    procedure SetInputEnabled(const AEnabled: Boolean);
    procedure ApplyInputEnabled;
    procedure RegisterSystems; override;
  public
    constructor Create(const ARoot: TCastleAbstractRootTransform;
      const AFactory: IEntityFactory; const AViewport: TCastleViewport);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    function Press(const Event: TInputPressRelease): Boolean; override;
    procedure SpawnMainPlayer;
    procedure HandleJoinAccept(const AEntityId: TEntityId; const APosX, APosY, APosZ, ARotY: Single); override;
    procedure InitMainPlayerOverlay(const AHeroTransform: TCastleTransform);
    property MainPlayerId: TEntityId read FMainPlayerId write FMainPlayerId;
    property MainPlayerTransform: TCastleTransform read FMainPlayerTransform;
    property Viewport: TCastleViewport read FViewport write FViewport;
    property NetSystem: TClientNetSystem read FNetSystem;
    property AuthSystem: TClientAuthSystem read FAuthSystem;
    property Rpc: TRpcClient read FRpc;
    property LobbyId: UInt32 read FLobbyId write FLobbyId;
    property ViewSystem: TGameViewSystem read FViewSystem;
    property Settings: TGameSettings read FSettings write FSettings;
    property Fsm: TClientGameFsm read FFsm;
    property InputEnabled: Boolean read FInputEnabled write SetInputEnabled;
  end;

implementation

uses ClientGameStates;

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
  FInputEnabled := True;
  FMainPlayerTransform := nil;
  FSettings := DefaultGameSettings;

  FFsm := TClientGameFsm.Create;
  FFsm.RegisterState(cgsWaiting, TClientWaitingState.Create(Self));
  FFsm.RegisterState(cgsMainMenu, TClientMainMenuState.Create(Self));
  FFsm.RegisterState(cgsSettings, TClientSettingsState.Create(Self));
  FFsm.RegisterState(cgsPlaying, TClientPlayingState.Create(Self));
  FFsm.ChangeState(cgsWaiting);
end;

destructor TGameWorldClient.Destroy;
begin
  FFsm.Free;
  FreeAndNil(FMouseLookUi);
  FRpc.Free;
  inherited;
end;

procedure TGameWorldClient.Update(const SecondsPassed: Single);
begin
  FFsm.Update(SecondsPassed);
  inherited Update(SecondsPassed);
end;

procedure TGameWorldClient.InitMainPlayerOverlay(const AHeroTransform: TCastleTransform);
begin
  FMainPlayerTransform := AHeroTransform;
  ApplyInputEnabled;
  if FMouseLookUi <> nil then
    FreeAndNil(FMouseLookUi);
  FMouseLookUi := TMouseLookOverlay.Create(FViewport.Owner);
  FMouseLookUi.FullSize := true;
  FMouseLookUi.Viewport := FViewport;
  FMouseLookUi.Hero := AHeroTransform;
  FViewport.InsertBack(FMouseLookUi);
end;

procedure TGameWorldClient.SetInputEnabled(const AEnabled: Boolean);
begin
  if FInputEnabled = AEnabled then Exit;
  FInputEnabled := AEnabled;
  ApplyInputEnabled;
end;

procedure TGameWorldClient.ApplyInputEnabled;
var
  CC: TCharacterControllerBehavior;
  FC: TFirstPersonCameraBehavior;
begin
  if FMainPlayerTransform = nil then Exit;
  CC := FMainPlayerTransform.FindBehavior(TCharacterControllerBehavior) as TCharacterControllerBehavior;
  if CC <> nil then
    CC.InputEnabled := FInputEnabled;
  FC := FMainPlayerTransform.FindBehavior(TFirstPersonCameraBehavior) as TFirstPersonCameraBehavior;
  if FC <> nil then
    FC.InputEnabled := FInputEnabled;
end;

function TGameWorldClient.Press(const Event: TInputPressRelease): Boolean;
begin
  if not FInputEnabled then
    Exit(False);
  Result := inherited Press(Event);
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
  // Entity.Rotation := ARotY; РІСЂР°С‰Р°С‚СЊ СЂРѕРѕС‚ РёР»Рё РІРёР·СѓР°Р»?
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
