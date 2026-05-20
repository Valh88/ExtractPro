unit ServerNetSystem;

{$mode objfpc}{$H+}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes, WorldSystemBase, CastleKeysMouse, CastleVectors, CastleTransform,
  RNL, NetMessages, NetServer, GameWorld, Interfaces;

type
  TServerNetLogEvent = procedure(Sender: TObject; const Msg: String) of object;

  TServerNetSystem = class(TWorldSystemBase)
  private
    FServer: TGameServer;
    FOnLog: TServerNetLogEvent;
    function GetOnConnect: TServerConnectEvent;
    procedure SetOnConnect(const AValue: TServerConnectEvent);
    function GetOnDisconnect: TServerDisconnectEvent;
    procedure SetOnDisconnect(const AValue: TServerDisconnectEvent);
    function GetOnReceive: TServerReceiveEvent;
    procedure SetOnReceive(const AValue: TServerReceiveEvent);
  public
    constructor Create(AWorldObj: TGameWorld; APort: Word; AMaxPlayers: Integer);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    procedure StartServer;
    procedure StopServer;
    function SendTo(APeer: TRNLPeer; const Msg: TNetMessage): Boolean;
    function SendToPlayer(APlayerId: UInt32; const Msg: TNetMessage): Boolean;
    procedure Broadcast(const Msg: TNetMessage);
    procedure BroadcastExcept(const Msg: TNetMessage; AExcludePlayerId: UInt32);
    procedure OnPlayerConnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
    procedure OnPlayerDisconnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
    procedure OnPlayerReceive(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32; const Msg: TNetMessage);
    procedure Log(const Msg: String);
    property Server: TGameServer read FServer;
    property OnConnect: TServerConnectEvent read GetOnConnect write SetOnConnect;
    property OnDisconnect: TServerDisconnectEvent read GetOnDisconnect write SetOnDisconnect;
    property OnReceive: TServerReceiveEvent read GetOnReceive write SetOnReceive;
    property OnLog: TServerNetLogEvent read FOnLog write FOnLog;
  end;

implementation

{ TServerNetSystem }

constructor TServerNetSystem.Create(AWorldObj: TGameWorld; APort: Word; AMaxPlayers: Integer);
begin
  inherited Create(AWorldObj);
  FServer := TGameServer.Create(APort, AMaxPlayers);
  OnConnect := @OnPlayerConnected;
  OnDisconnect := @OnPlayerDisconnected;
  OnReceive := @OnPlayerReceive;
end;

destructor TServerNetSystem.Destroy;
begin
  StopServer;
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
begin
  FServer.Service(0);
end;

function TServerNetSystem.SendTo(APeer: TRNLPeer; const Msg: TNetMessage): Boolean;
begin
  Result := FServer.SendTo(APeer, Msg);
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

procedure TServerNetSystem.OnPlayerConnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
var
  E: IGameEntity;
  Spawn: TEntitySpawnData;
  M: TNetMessage;
begin
  Log('Player connected: ' + PlayerId.ToString);

  E := WorldObj.Factory.CreatePlayerEntity(WorldObj.AllocateEntityId);
  E.Transform.Translation := CastleVectors.Vector3(0, 5, 0);
  WorldObj.AddPlayer(E);

  FServer.SetPeerEntityId(Peer, E.EntityId);

  Spawn.EntityId := E.EntityId;
  Spawn.PosX := 0; Spawn.PosY := 5; Spawn.PosZ := 0;
  Spawn.RotY := E.Rotation;
  M.Init(msgJoinAccept, Spawn.ToBytes);
  SendTo(Peer, M);
end;

procedure TServerNetSystem.OnPlayerDisconnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
var
  EntityId: UInt32;
begin
  Log('Player disconnected: ' + PlayerId.ToString);
  EntityId := FServer.GetPeerEntityId(Peer);
  if EntityId <> 0 then
  begin
    WorldObj.World.UnregisterEntity(EntityId);
    WorldObj.RemoveEntity(EntityId);
  end;
end;

procedure TServerNetSystem.OnPlayerReceive(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32; const Msg: TNetMessage);
var
  State: TPlayerStateData;
  E: IGameEntity;
  VisRoot: TCastleTransform;
  I: Integer;
begin
  case Msg.Header.MsgType of
    msgPlayerState:
    begin
      if TPlayerStateData.FromBytes(Msg.Payload, State) then
      begin
        E := WorldObj.FindEntity(State.EntityId);
        if E <> nil then
        begin
          E.Transform.Translation := CastleVectors.Vector3(State.PosX, State.PosY, State.PosZ);
          E.Rotation := State.RotY;
          VisRoot := nil;
          for I := 0 to E.Transform.Count - 1 do
            if E.Transform.Items[I].Name = 'VisualRoot' then
            begin
              VisRoot := E.Transform.Items[I];
              Break;
            end;
          if VisRoot <> nil then
            VisRoot.Rotation := CastleVectors.Vector4(0, 1, 0, 0);
        end;
      end;
    end;
  end;
end;

end.
