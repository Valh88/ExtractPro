unit ClientNetSystem;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes, WorldSystemBase, CastleKeysMouse, CastleVectors, CastleTransform,
  RNL, NetMessages, NetClient, GameWorld, help_types, Interfaces,
  ClientPlayerSyncBehavior, ClientSnapshotSystem, BulletTimer;

type
  TClientNetSystem = class(TWorldSystemBase)
  private
    FClient: TGameClient;
    FHost: string;
    FPort: Word;
    FMaxRetries: Integer;
    FRetryDelay: Single;
    FRetryCount: Integer;
    FRetryTimer: Single;
    FConnectTimer: Single;
    FNetTimer: Single;
    FWantDisconnect: Boolean;
    FConnected: Boolean;
    FLastError: string;
    FMyEntityId: TEntityId;
    FSnapSystem: TClientSnapshotSystem;
    FDefaultSendProc: TSendMessageProc;
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
    procedure Connect(const AHost: string; APort: Word);
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
    property DefaultSendProc: TSendMessageProc read FDefaultSendProc write FDefaultSendProc;
    property MyEntityId: TEntityId read FMyEntityId;
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
  FNetTimer := 0;
  FMyEntityId := 0;
  FWantDisconnect := False;
  FConnected := False;

  Connect('127.0.0.1', 7777);
end;

destructor TClientNetSystem.Destroy;
begin
  FConnected := False;
  FreeAndNil(FClient);
  inherited;
end;

procedure TClientNetSystem.Connect(const AHost: string; APort: Word);
begin
  FHost := AHost;
  FPort := APort;
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
  FNetTimer := 0;
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

  FNetTimer := FNetTimer + SecondsPassed;
  if FNetTimer >= 0.06 then
  begin
    if FClient.State <> csDisconnected then
      FClient.Service();
    FNetTimer := 0;
  end;
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
begin
  FRetryCount := 0;
  FRetryTimer := 0;
  FLastError := '';

  M.Init(msgJoinReq, [1]); // version
  if Assigned(FDefaultSendProc) then
    FDefaultSendProc(M, NET_CH_RELIABLE)
  else
    FClient.Send(M);
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
  Hit: THitData;
begin
  case Msg.Header.MsgType of
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
        if FSnapSystem <> nil then
          FSnapSystem.HandleSnapshot(Snap);
    end;
    msgShot:
    begin
      if TShotData.FromBytes(Msg.Payload, Shot) then
      begin
        if Shot.OwnerEntityId <> FMyEntityId then
        begin
          Bullet := WorldObj.Factory.CreateBulletEntity(WorldObj.AllocateEntityId);
          Bullet.Transform.Translation := Vector3(Shot.OriginX, Shot.OriginY, Shot.OriginZ)
            + Vector3(Shot.DirX, Shot.DirY, Shot.DirZ) * 1.0;
          Bullet.Transform.RigidBody.LinearVelocity := Vector3(Shot.DirX, Shot.DirY, Shot.DirZ) * 20;
          B := Bullet.Transform.FindBehavior(TBulletBehavior) as TBulletBehavior;
          if B <> nil then
            B.GameWorld := nil;
          WorldObj.AddBullet(Bullet, Shot.OwnerEntityId);
        end;
      end;
    end;
    msgHit:
    begin
      if THitData.FromBytes(Msg.Payload, Hit) then
        WriteLn('[Hit] target:', Hit.TargetEntityId,
          ' damage:', Hit.DamageAmount:0:0,
          ' source:', Hit.SourceEntityId);
    end;
  end;
end;

end.
