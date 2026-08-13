unit ClientNetSystem;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes, WorldSystemBase, CastleKeysMouse, CastleVectors, CastleTransform,
  RNL, NetMessages, NetClient, GameWorld, help_types, Interfaces,
  ClientPlayerSyncBehavior, ClientSnapshotSystem, BulletTimer, RpcClient,
  ClientEventBus, CastleLog;

type
  TSendMessageProc = reference to procedure(const M: TNetMessage; const AChannel: Integer);

  TClientNetSystem = class(TWorldSystemBase)
  private
    FClient: TGameClient;
    FHost: string;
    FPort: Word;
    FLobbyId: UInt32;
    FLobbyPlayerId: UInt32;
    FMaxRetries: Integer;
    FRetryDelay: Single;
    FRetryCount: Integer;
    FRetryTimer: Single;
    FConnectTimer: Single;
    FWantDisconnect: Boolean;
    FConnected: Boolean;
    FLastError: string;
    FMyEntityId: TEntityId;
    FSnapSystem: TClientSnapshotSystem;
    FRpc: TRpcClient;
    FDefaultSendProc: TSendMessageProc;
    FConnectedReported: Boolean;
    FOnDeny: TNotifyEvent;
    FDenyReason: string;
    FAuthToken: string;
    function GetState: TClientState;
    function GetOnConnected: TClientConnectEvent;
    procedure SetOnConnected(const AValue: TClientConnectEvent);
    function GetOnDisconnected: TClientDisconnectEvent;
    procedure SetOnDisconnected(const AValue: TClientDisconnectEvent);
    function GetOnReceive: TClientReceiveEvent;
    procedure SetOnReceive(const AValue: TClientReceiveEvent);
    procedure OnClientConnected(Sender: TObject);
    procedure OnClientDisconnected(Sender: TObject);
    procedure OnClientReceive(Sender: TObject; const Msg: TNetMessage);
    procedure DoConnect;
  public
    constructor Create(AWorldObj: TGameWorld; AMaxRetries: Integer = 3; ARetryDelay: Single = 2.0);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    procedure Connect(const AHost: string; APort: Word; const ALobbyId: UInt32 = 1);
    procedure Disconnect;
    function Send(const Msg: TNetMessage): Boolean;
    function SendToChannel(const Msg: TNetMessage; AChannel: Integer): Boolean;
    property Client: TGameClient read FClient;
    property State: TClientState read GetState;
    property LastError: string read FLastError;
    property OnConnected: TClientConnectEvent read GetOnConnected write SetOnConnected;
    property OnDisconnected: TClientDisconnectEvent read GetOnDisconnected write SetOnDisconnected;
    property OnReceive: TClientReceiveEvent read GetOnReceive write SetOnReceive;
    property SnapSystem: TClientSnapshotSystem read FSnapSystem write FSnapSystem;
    property Rpc: TRpcClient read FRpc write FRpc;
    property DefaultSendProc: TSendMessageProc read FDefaultSendProc write FDefaultSendProc;
    property MyEntityId: TEntityId read FMyEntityId;
    property AuthToken: string read FAuthToken write FAuthToken;
    property LobbyPlayerId: UInt32 read FLobbyPlayerId write FLobbyPlayerId;
    property OnDeny: TNotifyEvent read FOnDeny write FOnDeny;
    property DenyReason: string read FDenyReason;
  end;

implementation

{ TClientNetSystem }

constructor TClientNetSystem.Create(AWorldObj: TGameWorld; AMaxRetries: Integer; ARetryDelay: Single);
begin
  inherited Create(AWorldObj);
  FClient := nil;
  FMaxRetries := AMaxRetries;
  FRetryDelay := ARetryDelay;
  FRetryCount := 0;
  FRetryTimer := 0;
  FConnectTimer := 0;
  FMyEntityId := 0;
  FWantDisconnect := False;
  FConnected := False;
  FAuthToken := '';
  FDenyReason := '';
  FOnDeny := nil;
  FLobbyId := 1;
  FLobbyPlayerId := 0;
  FRpc := nil;
  FConnectedReported := False;
end;

destructor TClientNetSystem.Destroy;
begin
  FConnected := False;
  FreeAndNil(FClient);
  inherited;
end;

procedure TClientNetSystem.Connect(const AHost: string; APort: Word; const ALobbyId: UInt32);
begin
  FHost := AHost;
  FPort := APort;
  FLobbyId := ALobbyId;
  FRetryCount := 0;
  FRetryTimer := 0;
  FConnectTimer := 0;
  FWantDisconnect := False;
  FConnected := True;
  FLastError := '';
  DoConnect;
end;

procedure TClientNetSystem.Disconnect;
begin
  FWantDisconnect := True;
  FConnected := False;
  FRetryCount := FMaxRetries;
  FRetryTimer := 0;
  FConnectTimer := 0;
  FreeAndNil(FClient);
end;

procedure TClientNetSystem.DoConnect;
begin
  FreeAndNil(FClient);
  FClient := TGameClient.Create;
  FClient.OnConnected := @OnClientConnected;
  FClient.OnDisconnected := @OnClientDisconnected;
  FClient.OnReceive := @OnClientReceive;
  try
    FClient.Connect(FHost, FPort);
  except
    on E: Exception do
      FreeAndNil(FClient);
  end;
end;

function TClientNetSystem.Send(const Msg: TNetMessage): Boolean;
begin
  if FClient <> nil then
    Result := FClient.Send(Msg)
  else
    Result := False;
end;

function TClientNetSystem.SendToChannel(const Msg: TNetMessage; AChannel: Integer): Boolean;
begin
  if FClient <> nil then
    Result := FClient.Send(Msg, AChannel)
  else
    Result := False;
end;

procedure TClientNetSystem.Update(const SecondsPassed: Single);
begin
  if FClient = nil then Exit;

  if FClient.State <> csDisconnected then
    FClient.Service();

  if (FClient.State = csDisconnected) and FConnected and (FRetryCount < FMaxRetries) then
  begin
    FRetryTimer := FRetryTimer + SecondsPassed;
    if FRetryTimer >= FRetryDelay then
    begin
      Inc(FRetryCount);
      FRetryTimer := 0;
      DoConnect;
    end;
  end;
end;

function TClientNetSystem.GetState: TClientState;
begin
  if FClient <> nil then
    Result := FClient.State
  else
    Result := csDisconnected;
end;

function TClientNetSystem.GetOnConnected: TClientConnectEvent;
begin
  if FClient <> nil then
    Result := FClient.OnConnected
  else
    Result := nil;
end;

procedure TClientNetSystem.SetOnConnected(const AValue: TClientConnectEvent);
begin
  if FClient <> nil then
    FClient.OnConnected := AValue;
end;

function TClientNetSystem.GetOnDisconnected: TClientDisconnectEvent;
begin
  if FClient <> nil then
    Result := FClient.OnDisconnected
  else
    Result := nil;
end;

procedure TClientNetSystem.SetOnDisconnected(const AValue: TClientDisconnectEvent);
begin
  if FClient <> nil then
    FClient.OnDisconnected := AValue;
end;

function TClientNetSystem.GetOnReceive: TClientReceiveEvent;
begin
  if FClient <> nil then
    Result := FClient.OnReceive
  else
    Result := nil;
end;

procedure TClientNetSystem.SetOnReceive(const AValue: TClientReceiveEvent);
begin
  if FClient <> nil then
    FClient.OnReceive := AValue;
end;

procedure TClientNetSystem.OnClientConnected(Sender: TObject);
var
  M: TNetMessage;
  AuthData: TAuthPayload;
  JoinData: TJoinReqData;
  i: Integer;
begin
  FRetryCount := 0;
  FRetryTimer := 0;
  FLastError := '';
  if FAuthToken <> '' then
  begin
    FillChar(AuthData, SizeOf(AuthData), 0);
    for i := 1 to Length(FAuthToken) do
      if i <= 64 then
        AuthData.Token[i - 1] := AnsiChar(FAuthToken[i]);
    M.Init(msgAuth, AuthData.ToBytes);
    if Assigned(FDefaultSendProc) then
      FDefaultSendProc(M, NET_CH_RELIABLE)
    else
      FClient.Send(M);
  end;

  JoinData.LobbyId := FLobbyId;
  JoinData.LobbyPlayerId := FLobbyPlayerId;
  JoinData.Version := 1;
  M.Init(msgJoinReq, JoinData.ToBytes);
  if FClient <> nil then
    FClient.Send(M, NET_CH_RELIABLE);
end;

procedure TClientNetSystem.OnClientDisconnected(Sender: TObject);
begin
  FMyEntityId := 0;
  if not FWantDisconnect then
  begin
    if FRetryCount < FMaxRetries then
      FLastError := 'Connection lost. Retrying...'
    else
      FLastError := 'Connection lost. Max retries reached.';
  end;
end;

procedure TClientNetSystem.OnClientReceive(Sender: TObject; const Msg: TNetMessage);
var
  Spawn: TEntitySpawnData;
  Entity: IGameEntity;
  SendProc: TSendMessageProc;
  Snap: TSnapshotData;
  Shot: TShotData;
  Bullet: IGameEntity;
  B: TBulletBehavior;
  DenyCode: string;
  E: TClientGameEvent;
  PartyInfo: TPartyInfoData;
  PartyPayload: TPartyInfoPayload;
  ZoneEv: TExtractZoneEvent;
  ZonePayload: TExtractZonePayload;
  Hit: THitData;
  i: Integer;
begin
  if not FConnectedReported then
  begin
    FConnectedReported := True;
    OnClientConnected(Self);
  end;

  case Msg.Header.MsgType of
    msgJoinDeny:
    begin
      if Length(Msg.Payload) >= 3 then
        DenyCode := Chr(Msg.Payload[0]) + Chr(Msg.Payload[1]) + Chr(Msg.Payload[2])
      else
        DenyCode := '?';
      FDenyReason := 'Join denied: ' + DenyCode;
      FLastError := FDenyReason;
      if Assigned(FOnDeny) then
        FOnDeny(Self);
    end;
    msgJoinAccept:
    begin
      if TEntitySpawnData.FromBytes(Msg.Payload, Spawn) then
      begin
        FMyEntityId := Spawn.EntityId;
        if FSnapSystem <> nil then
          FSnapSystem.SetLocalPlayerId(FMyEntityId);
        WorldObj.HandleJoinAccept(Spawn.EntityId, Spawn.PosX, Spawn.PosY, Spawn.PosZ, Spawn.RotY);
        Entity := WorldObj.FindEntity(Spawn.EntityId);
        if Entity <> nil then
        begin
          SendProc := FDefaultSendProc;
          if not Assigned(SendProc) then
            SendProc := procedure(const M: TNetMessage; const AChannel: Integer)
            begin
              if FClient <> nil then
                FClient.Send(M, AChannel);
            end;
          Entity.Transform.AddBehavior(
            TClientPlayerSync.Create(Entity.Transform, Spawn.EntityId, SendProc));
        end;
      end;
    end;
    msgSnapshot:
    begin
      if TSnapshotData.FromBytes(Msg.Payload, Snap) then
      begin
        if FSnapSystem <> nil then
          FSnapSystem.HandleSnapshot(Snap);
      end;
    end;
    msgShot:
    begin
      if TShotData.FromBytes(Msg.Payload, Shot) then
      begin
        if Shot.OwnerEntityId <> FMyEntityId then
        begin
          Bullet := WorldObj.Factory.CreateBulletEntity(WorldObj.AllocateEntityId);
          Bullet.Transform.Translation := Vector3(Shot.OriginX, Shot.OriginY, Shot.OriginZ)
            + Vector3(Shot.DirX, Shot.DirY, Shot.DirZ) * 3.0
            + Vector3(0, 0.5, 0);
          Bullet.Transform.RigidBody.LinearVelocity := Vector3(Shot.DirX, Shot.DirY, Shot.DirZ) * 20;
          B := Bullet.Transform.FindBehavior(TBulletBehavior) as TBulletBehavior;
          if B <> nil then
            B.GameWorld := nil;
          WorldObj.AddBullet(Bullet, Shot.OwnerEntityId);
        end;
      end;
    end;
    msgDespawn:
    begin
      if Length(Msg.Payload) >= 4 then
        WorldObj.World.UnregisterEntity(
          Msg.Payload[0] or (Msg.Payload[1] shl 8) or
          (Msg.Payload[2] shl 16) or (Msg.Payload[3] shl 24));
    end;
    msgHit:
    begin
      if THitData.FromBytes(Msg.Payload, Hit) then
        WritelnLog('Client', 'Hit: entity %d got %.1f damage from entity %d',
          [Hit.TargetEntityId, Hit.DamageAmount, Hit.SourceEntityId]);
    end;
    msgExtractZone:
    begin
      if TExtractZoneEvent.FromBytes(Msg.Payload, ZoneEv) then
      begin
        ZonePayload := TExtractZonePayload.Create;
        ZonePayload.EntityId := ZoneEv.EntityId;
        ZonePayload.ZoneIndex := ZoneEv.ZoneIndex;
        ZonePayload.PosX := ZoneEv.PosX;
        ZonePayload.PosY := ZoneEv.PosY;
        ZonePayload.PosZ := ZoneEv.PosZ;
        if ZoneEv.Entered = 1 then
          E.EventType := cgeExtractZoneEntered
        else if ZoneEv.Entered = 2 then
          E.EventType := cgeExtractZoneCancelled
        else
          E.EventType := cgeExtractZoneExited;
        E.Amount := ZoneEv.ZoneIndex;
        E.Data := ZonePayload;
        GlobalClientEventBus.Queue(E);
        GlobalClientEventBus.Flush;
      end;
    end;
    msgRpcResponse:
    begin
      if FRpc <> nil then
        FRpc.DispatchResponse(Msg.Header.CorrelationId, Msg.Payload);
    end;
    msgGameStateChanged:
    begin
      if Length(Msg.Payload) >= 1 then
      begin
        E.EventType := cgeGameStateChanged;
        E.Amount := Msg.Payload[0];
        E.Data := nil;
        GlobalClientEventBus.Queue(E);
        GlobalClientEventBus.Flush;
      end;
    end;
    msgPartyInfo:
    begin
      if TPartyInfoData.FromBytes(Msg.Payload, PartyInfo) then
      begin
        PartyPayload := TPartyInfoPayload.Create;
        PartyPayload.TeamIndex := PartyInfo.TeamIndex;
        SetLength(PartyPayload.Members, PartyInfo.MemberCount);
        for i := 0 to High(PartyPayload.Members) do
          PartyPayload.Members[i] := PartyInfo.MemberIds[i];
        E.EventType := cgePartyInfo;
        E.Amount := 0;
        E.Data := PartyPayload;
        GlobalClientEventBus.Queue(E);
        GlobalClientEventBus.Flush;
      end;
    end;
  end;
end;

end.
