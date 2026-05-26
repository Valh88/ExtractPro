unit ServerNetSystem;

{$mode objfpc}{$H+}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes, WorldSystemBase, CastleKeysMouse, CastleVectors, CastleTransform,
  RNL, NetMessages, NetServer, GameWorld, Interfaces,
  ServerPlayerSyncBehavior, ServerShotSystem, AuthTypes, RpcServer, RpcTypes;

type
  TServerNetLogEvent = procedure(Sender: TObject; const Msg: String) of object;

  TPendingJoin = record
    Peer: TRNLPeer;
    PlayerId: UInt32;
    LobbyId: UInt32;
    Authenticated: Boolean;
    Timeout: Single;
  end;

  TServerNetSystem = class(TWorldSystemBase)
  private
    FServer: TGameServer;
    FShotSystem: TServerShotSystem;
    FRpc: TRpcServer;
    FOnLog: TServerNetLogEvent;
    FPendingJoin: array of TPendingJoin;
    FRequireAuth: Boolean;
    FValidator: IAuthValidator;
    function GetOnConnect: TServerConnectEvent;
    procedure SetOnConnect(const AValue: TServerConnectEvent);
    function GetOnDisconnect: TServerDisconnectEvent;
    procedure SetOnDisconnect(const AValue: TServerDisconnectEvent);
    function GetOnReceive: TServerReceiveEvent;
    procedure SetOnReceive(const AValue: TServerReceiveEvent);
    procedure CleanPendingJoin;
    function FindPendingJoin(Peer: TRNLPeer): Integer;
    procedure SpawnPlayer(Peer: TRNLPeer; APlayerId: UInt32);
  public
    constructor Create(AWorldObj: TGameWorld; APort: Word; AMaxPlayers: Integer);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    procedure StartServer;
    procedure StopServer;
    function SendTo(Peer: TRNLPeer; const Msg: TNetMessage): Boolean;
    function SendToPlayer(APlayerId: UInt32; const Msg: TNetMessage): Boolean;
    procedure Broadcast(const Msg: TNetMessage);
    procedure BroadcastExcept(const Msg: TNetMessage; AExcludePlayerId: UInt32);
    procedure OnPlayerConnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
    procedure OnPlayerDisconnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
    procedure OnPlayerReceive(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32; const Msg: TNetMessage);
    procedure HandleRpcRequest(Peer: TRNLPeer; const Msg: TNetMessage);
    procedure Log(const Msg: String);
    property Server: TGameServer read FServer;
    property Rpc: TRpcServer read FRpc;
    property ShotSystem: TServerShotSystem read FShotSystem write FShotSystem;
    property OnConnect: TServerConnectEvent read GetOnConnect write SetOnConnect;
    property OnDisconnect: TServerDisconnectEvent read GetOnDisconnect write SetOnDisconnect;
    property OnReceive: TServerReceiveEvent read GetOnReceive write SetOnReceive;
    property OnLog: TServerNetLogEvent read FOnLog write FOnLog;
    property RequireAuth: Boolean read FRequireAuth write FRequireAuth;
    property AuthValidator: IAuthValidator read FValidator write FValidator;
  end;

implementation

type
  TRpcReplyCtx = class
    Peer: TRNLPeer;
    CorrelationId: TGuid;
    Net: TServerNetSystem;
    procedure Reply(const RespPayload: TBytes);
  end;

{ TRpcReplyCtx }

procedure TRpcReplyCtx.Reply(const RespPayload: TBytes);
var
  Resp: TNetMessage;
begin
  Resp.Init(msgRpcResponse, RespPayload);
  Resp.Header.CorrelationId := CorrelationId;
  Net.SendTo(Peer, Resp);
  Free;
end;

{ TServerNetSystem }

constructor TServerNetSystem.Create(AWorldObj: TGameWorld; APort: Word; AMaxPlayers: Integer);
begin
  inherited Create(AWorldObj);
  FServer := TGameServer.Create(APort, AMaxPlayers);
  OnConnect := @OnPlayerConnected;
  OnDisconnect := @OnPlayerDisconnected;
  OnReceive := @OnPlayerReceive;
  FRequireAuth := False;
  FValidator := nil;
  FPendingJoin := nil;
  FRpc := TRpcServer.Create;
end;

destructor TServerNetSystem.Destroy;
begin
  StopServer;
  FRpc.Free;
  FServer.Free;
  inherited;
end;

function TServerNetSystem.GetOnConnect: TServerConnectEvent;
begin
  Result := FServer.OnConnect;
end;

procedure TServerNetSystem.SetOnConnect(const AValue: TServerConnectEvent);
begin
  FServer.OnConnect := AValue;
end;

function TServerNetSystem.GetOnDisconnect: TServerDisconnectEvent;
begin
  Result := FServer.OnDisconnect;
end;

procedure TServerNetSystem.SetOnDisconnect(const AValue: TServerDisconnectEvent);
begin
  FServer.OnDisconnect := AValue;
end;

function TServerNetSystem.GetOnReceive: TServerReceiveEvent;
begin
  Result := FServer.OnReceive;
end;

procedure TServerNetSystem.SetOnReceive(const AValue: TServerReceiveEvent);
begin
  FServer.OnReceive := AValue;
end;

procedure TServerNetSystem.StartServer;
begin
  FServer.Start;
end;

procedure TServerNetSystem.StopServer;
begin
  FServer.Stop;
end;

procedure TServerNetSystem.Update(const SecondsPassed: Single);
var
  i: Integer;
  M: TNetMessage;
begin
  FServer.Service(0);
  i := 0;
  while i < Length(FPendingJoin) do
  begin
    FPendingJoin[i].Timeout := FPendingJoin[i].Timeout - SecondsPassed;
    if FPendingJoin[i].Timeout <= 0 then
    begin
      Log('Join timeout for player ' + FPendingJoin[i].PlayerId.ToString);
      M.Init(msgJoinDeny, [Byte(Ord('T')), Byte(Ord('O'))]);
      SendTo(FPendingJoin[i].Peer, M);
      FPendingJoin[i].Peer.Disconnect;
      FPendingJoin[i] := FPendingJoin[High(FPendingJoin)];
      SetLength(FPendingJoin, Length(FPendingJoin) - 1);
    end
    else
      Inc(i);
  end;
end;

function TServerNetSystem.SendTo(Peer: TRNLPeer; const Msg: TNetMessage): Boolean;
begin
  Result := FServer.SendTo(Peer, Msg);
end;

function TServerNetSystem.SendToPlayer(APlayerId: UInt32; const Msg: TNetMessage): Boolean;
begin
  Result := FServer.SendToPlayer(APlayerId, Msg);
end;

procedure TServerNetSystem.Broadcast(const Msg: TNetMessage);
begin
  FServer.Broadcast(Msg);
end;

procedure TServerNetSystem.BroadcastExcept(const Msg: TNetMessage; AExcludePlayerId: UInt32);
begin
  FServer.BroadcastExcept(Msg, AExcludePlayerId);
end;

procedure TServerNetSystem.Log(const Msg: String);
begin
  if Assigned(FOnLog) then
    FOnLog(Self, Msg)
  else
    WriteLn(Msg);
end;

function TServerNetSystem.FindPendingJoin(Peer: TRNLPeer): Integer;
begin
  for Result := 0 to High(FPendingJoin) do
    if FPendingJoin[Result].Peer = Peer then
      Exit;
  Result := -1;
end;

procedure TServerNetSystem.CleanPendingJoin;
var
  i: Integer;
begin
  for i := High(FPendingJoin) downto 0 do
    if FPendingJoin[i].Peer = nil then
    begin
      FPendingJoin[i] := FPendingJoin[High(FPendingJoin)];
      SetLength(FPendingJoin, Length(FPendingJoin) - 1);
    end;
end;

procedure TServerNetSystem.SpawnPlayer(Peer: TRNLPeer; APlayerId: UInt32);
var
  E: IGameEntity;
  Spawn: TEntitySpawnData;
  M: TNetMessage;
begin
  E := WorldObj.Factory.CreatePlayerEntity(WorldObj.AllocateEntityId);
  E.Transform.Translation := CastleVectors.Vector3(0, 5, 0);
  if E.Transform.RigidBody <> nil then
  begin
    E.Transform.RigidBody.Dynamic := False;
    E.Transform.RigidBody.Animated := True;
  end;
  WorldObj.AddPlayer(E);
  E.Transform.AddBehavior(TServerPlayerSync.Create(E.Transform, E.EntityId));
  FServer.SetPeerEntityId(Peer, E.EntityId);
  Spawn.EntityId := E.EntityId;
  Spawn.PosX := 0; Spawn.PosY := 5; Spawn.PosZ := 0;
  Spawn.RotY := E.Rotation;
  M.Init(msgJoinAccept, Spawn.ToBytes);
  SendTo(Peer, M);
end;

procedure TServerNetSystem.OnPlayerConnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
var
  L: Integer;
begin
  Log('Player connected: ' + PlayerId.ToString);
  if not FRequireAuth then
    SpawnPlayer(Peer, PlayerId)
  else
  begin
    L := Length(FPendingJoin);
    SetLength(FPendingJoin, L + 1);
    FPendingJoin[L].Peer := Peer;
    FPendingJoin[L].PlayerId := PlayerId;
    FPendingJoin[L].LobbyId := 0;
    FPendingJoin[L].Authenticated := False;
    FPendingJoin[L].Timeout := 10;
  end;
end;

procedure TServerNetSystem.OnPlayerDisconnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
var
  Idx: Integer;
  EntityId: UInt32;
begin
  Log('Player disconnected: ' + PlayerId.ToString);
  Idx := FindPendingJoin(Peer);
  if Idx <> -1 then
  begin
    FPendingJoin[Idx] := FPendingJoin[High(FPendingJoin)];
    SetLength(FPendingJoin, Length(FPendingJoin) - 1);
    Exit;
  end;
  EntityId := FServer.GetPeerEntityId(Peer);
  if EntityId <> 0 then
  begin
    WorldObj.World.UnregisterEntity(EntityId);
    WorldObj.RemoveEntity(EntityId);
  end;
end;

procedure TServerNetSystem.HandleRpcRequest(Peer: TRNLPeer; const Msg: TNetMessage);
var
  Ctx: TRpcReplyCtx;
begin
  if Length(Msg.Payload) < 1 then Exit;
  Ctx := TRpcReplyCtx.Create;
  Ctx.Net := Self;
  Ctx.Peer := Peer;
  Ctx.CorrelationId := Msg.Header.CorrelationId;
  if not FRpc.DispatchRequest(Msg.Payload[0],
    Copy(Msg.Payload, 1, Length(Msg.Payload) - 1),
    Msg.Header.CorrelationId, @Ctx.Reply) then
    Ctx.Free;
end;

procedure TServerNetSystem.OnPlayerReceive(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32; const Msg: TNetMessage);
var
  State: TPlayerStateData;
  ShotData: TShotData;
  E: IGameEntity;
  Sync: TServerPlayerSync;
  AuthData: TAuthPayload;
  JoinData: TJoinReqData;
  AuthToken: string;
  AuthResult: TAuthResult;
  M: TNetMessage;
  Idx: Integer;
begin
  case Msg.Header.MsgType of
    msgJoinReq:
    begin
      if not FRequireAuth then Exit;
      if TJoinReqData.FromBytes(Msg.Payload, JoinData) then
      begin
        Idx := FindPendingJoin(Peer);
        if Idx = -1 then Exit;
        FPendingJoin[Idx].LobbyId := JoinData.LobbyId;
        if FPendingJoin[Idx].Authenticated then
        begin
          FPendingJoin[Idx] := FPendingJoin[High(FPendingJoin)];
          SetLength(FPendingJoin, Length(FPendingJoin) - 1);
          Log('Player ' + PlayerId.ToString + ' joined lobby ' + JoinData.LobbyId.ToString);
          SpawnPlayer(Peer, PlayerId);
        end
        else
          Log('Player ' + PlayerId.ToString + ' waiting for auth (lobby ' + JoinData.LobbyId.ToString + ')');
      end;
    end;
    msgAuth:
    begin
      if not (FRequireAuth and (FValidator <> nil)) then
        Exit;
      if TAuthPayload.FromBytes(Msg.Payload, AuthData) then
      begin
        AuthToken := TrimRight(string(AuthData.Token));
        AuthResult := FValidator.ValidateToken(AuthToken);
        if AuthResult.Valid then
        begin
          Idx := FindPendingJoin(Peer);
          if Idx <> -1 then
          begin
            FPendingJoin[Idx].Authenticated := True;
            if FPendingJoin[Idx].LobbyId <> 0 then
            begin
              FPendingJoin[Idx] := FPendingJoin[High(FPendingJoin)];
              SetLength(FPendingJoin, Length(FPendingJoin) - 1);
              Log('Player ' + PlayerId.ToString + ' authenticated and joined');
              SpawnPlayer(Peer, PlayerId);
            end;
          end;
          Log('Player ' + PlayerId.ToString + ' authenticated as ' + AuthResult.Login);
        end
        else
        begin
          Log('Auth failed for player ' + PlayerId.ToString);
          M.Init(msgJoinDeny, [Byte(Ord('A')), Byte(Ord('U')), Byte(Ord('T'))]);
          SendTo(Peer, M);
          Peer.Disconnect;
        end;
      end;
    end;
    msgPlayerState:
    begin
      if TPlayerStateData.FromBytes(Msg.Payload, State) then
      begin
        E := WorldObj.FindEntity(State.EntityId);
        if E <> nil then
        begin
          Sync := E.Transform.FindBehavior(TServerPlayerSync) as TServerPlayerSync;
          if Sync <> nil then
            Sync.ApplyState(State);
        end;
      end;
    end;
    msgShot:
    begin
      if TShotData.FromBytes(Msg.Payload, ShotData) then
      begin
        if Assigned(FShotSystem) then
          FShotSystem.QueueShot(ShotData, PlayerId);
        BroadcastExcept(Msg, PlayerId);
      end;
    end;
    msgRpcRequest:
      HandleRpcRequest(Peer, Msg);
  end;
end;

end.