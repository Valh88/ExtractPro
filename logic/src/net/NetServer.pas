{
  NetServer.pas — обёртка RNL-сервера.

  ── Схема работы ───────────────────────────────────────────────────
    TGameServer (одна на рейд)

    ┌────���─────────────────────────────────────┐
    │ TGameServer                              │
    │  ┌──────────┐  ┌─────────────────────┐   │
    │  │ TRNLHost │──│ TServerPeerInfo[]    │   │
    │  └──────────┘  │  Peer + PlayerId     │   │
    │       │        └─────────────────────┘   │
    │  Service() ←────── OnConnect /           │
    │                  OnDisconnect /          │
    │                  OnReceive               │
    └──────────────────────────────────────────┘

  ── Использование ────────────────────���─────────────────────────────
    Server := TGameServer.Create(7777, 8);
    Server.OnConnect := @OnPlayerJoin;
    Server.OnReceive := @OnPlayerMsg;
    Server.Start;

    // в игровом цикле:
    while True do begin
      Server.Service(0);  // non-blocking
      // ... обновление мира
    end;

    Server.OnConnect := procedure(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32)
    begin
      // PlayerId можно привязать к TEntityId
      Msg.Init(msgJoinAccept);
      Server.SendTo(Peer, Msg);
    end;

    Server.OnReceive := procedure(Sender: TObject; Peer: TRNLPeer;
      PlayerId: UInt32; const Msg: TNetMessage)
    begin
      case Msg.Header.MsgType of
        msgInput: // применить ввод к игроку PlayerId
        msgChat:  // Server.Broadcast(Msg)
      end;
    end;

  ── Зависимости ────────────────────��───────────────────────────────
    RNL, NetMessages
}
unit NetServer;

{$mode objfpc}{$H+}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes,
  RNL,
  NetMessages;

type
  TServerPeerInfo = record
    Peer: TRNLPeer;
    PlayerId: UInt32;
    EntityId: UInt32;
    Connected: Boolean;
  end;

  TServerConnectEvent = reference to procedure(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
  TServerDisconnectEvent = reference to procedure(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
  TServerReceiveEvent = reference to procedure(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32; const Msg: TNetMessage);

  TGameServer = class
  private
    FInstance: TRNLInstance;
    FNetwork: TRNLRealNetwork;
    FHost: TRNLHost;
    FPort: Word;
    FMaxPlayers: Integer;
    FNextPlayerId: UInt32;
    FPeers: array of TServerPeerInfo;
    FEvent: TRNLHostEvent;
    FOnConnect: TServerConnectEvent;
    FOnDisconnect: TServerDisconnectEvent;
    FOnReceive: TServerReceiveEvent;
    function FindPeerIdx(APeer: TRNLPeer): Integer;
    function AllocPlayerId: UInt32;
    procedure ClearEvent;
  public
    constructor Create(APort: Word; AMaxPlayers: Integer);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    procedure Service(ATimeoutMs: Integer = 0);
    function SendTo(APeer: TRNLPeer; const Msg: TNetMessage): Boolean;
    function SendToPlayer(APlayerId: UInt32; const Msg: TNetMessage): Boolean;
    procedure Broadcast(const Msg: TNetMessage);
    procedure BroadcastExcept(const Msg: TNetMessage; AExcludePlayerId: UInt32);
    procedure SetPeerEntityId(APeer: TRNLPeer; AEntityId: UInt32);
    function GetPeerEntityId(APeer: TRNLPeer): UInt32;
    function GetPeerEntityIdByPlayerId(APlayerId: UInt32): UInt32;
    function FindPlayerIdByEntityId(AEntityId: UInt32): UInt32;
    property Host: TRNLHost read FHost;
    property Port: Word read FPort;
    property Peers: Integer read FMaxPlayers;
    property OnConnect: TServerConnectEvent read FOnConnect write FOnConnect;
    property OnDisconnect: TServerDisconnectEvent read FOnDisconnect write FOnDisconnect;
    property OnReceive: TServerReceiveEvent read FOnReceive write FOnReceive;
  end;

implementation

{ TGameServer }

constructor TGameServer.Create(APort: Word; AMaxPlayers: Integer);
begin
  inherited Create;
  FPort := APort;
  FMaxPlayers := AMaxPlayers;
  FNextPlayerId := 1;
  FInstance := TRNLInstance.Create;
  FNetwork := TRNLRealNetwork.Create(FInstance);
  FHost := TRNLHost.Create(FInstance, FNetwork);
  FHost.MaximumCountPeers := AMaxPlayers;
  FHost.AllowIncomingConnections := True;
  FHost.ChannelTypes[0] := RNL_PEER_UNRELIABLE_UNORDERED_CHANNEL;
  FHost.ChannelTypes[1] := RNL_PEER_RELIABLE_ORDERED_CHANNEL;
  FHost.ProtocolID := $5472616e73477269;
  FEvent.Initialize;
end;

destructor TGameServer.Destroy;
begin
  Stop;
  FEvent.Free;
  FHost.Free;
  FNetwork.Free;
  FInstance.Free;
  inherited;
end;

procedure TGameServer.Start;
var
  Addr: TRNLAddress;
begin
  Addr := TRNLAddress.CreateFromString('::' + ':' + IntToStr(FPort));
  FHost.Address^ := Addr;
  FHost.Start;
end;

procedure TGameServer.Stop;
begin
  if FHost <> nil then
    FHost.Flush;
  SetLength(FPeers, 0);
end;

function TGameServer.AllocPlayerId: UInt32;
begin
  Result := FNextPlayerId;
  Inc(FNextPlayerId);
end;

function TGameServer.FindPeerIdx(APeer: TRNLPeer): Integer;
begin
  for Result := 0 to High(FPeers) do
    if FPeers[Result].Peer = APeer then Exit;
  Result := -1;
end;

procedure TGameServer.ClearEvent;
begin
  FEvent.Type_ := RNL_HOST_EVENT_TYPE_NONE;
  FEvent.Peer := nil;
  FEvent.Message := nil;
end;

procedure TGameServer.Service(ATimeoutMs: Integer);
var
  Status: TRNLHostServiceStatus;
  Idx, Last: Integer;
  Info: TServerPeerInfo;
  Msg: TNetMessage;
  Bytes: TBytes;
  Peer: TRNLPeer;
begin
  ClearEvent;
  Status := FHost.Service(FEvent, ATimeoutMs);
  if Status <> RNL_HOST_SERVICE_STATUS_EVENT then Exit;

  Peer := FEvent.Peer;

  case FEvent.Type_ of
    RNL_HOST_EVENT_TYPE_PEER_CONNECT:
    begin
      Info.Peer := Peer;
      Info.PlayerId := AllocPlayerId;
      Info.Connected := True;
      SetLength(FPeers, Length(FPeers) + 1);
      FPeers[High(FPeers)] := Info;
      if Assigned(FOnConnect) then
        FOnConnect(Self, Peer, Info.PlayerId);
    end;

    RNL_HOST_EVENT_TYPE_PEER_DISCONNECT:
    begin
      Idx := FindPeerIdx(Peer);
      if Idx <> -1 then
      begin
        if Assigned(FOnDisconnect) then
          FOnDisconnect(Self, Peer, FPeers[Idx].PlayerId);
        Last := High(FPeers);
        if Idx < Last then
          FPeers[Idx] := FPeers[Last];
        SetLength(FPeers, Last);
      end;
    end;

    RNL_HOST_EVENT_TYPE_PEER_RECEIVE:
    begin
      if FEvent.Message = nil then Exit;
      Idx := FindPeerIdx(Peer);
      if Idx = -1 then Exit;
      Bytes := FEvent.Message.AsBytes;
      FEvent.Message.DecRef;
      FEvent.Message := nil;
      if TNetMessage.Unpack(Bytes, Msg) then
        if Assigned(FOnReceive) then
          FOnReceive(Self, Peer, FPeers[Idx].PlayerId, Msg);
    end;
  end;
end;

function TGameServer.SendTo(APeer: TRNLPeer; const Msg: TNetMessage): Boolean;
var
  Data: TBytes;
  RNLMsg: TRNLMessage;
begin
  Result := False;
  if APeer = nil then Exit;
  Data := Msg.Pack;
  RNLMsg := TRNLMessage.CreateFromBytes(Data);
  try
    APeer.Channels[NET_CH_RELIABLE].SendMessage(RNLMsg);
    Result := True;
  finally
    RNLMsg.DecRef;
  end;
end;

function TGameServer.SendToPlayer(APlayerId: UInt32; const Msg: TNetMessage): Boolean;
var
  i: Integer;
begin
  for i := 0 to High(FPeers) do
    if FPeers[i].Connected and (FPeers[i].PlayerId = APlayerId) then
      Exit(SendTo(FPeers[i].Peer, Msg));
  Result := False;
end;

procedure TGameServer.Broadcast(const Msg: TNetMessage);
var
  Data: TBytes;
  RNLMsg: TRNLMessage;
begin
  Data := Msg.Pack;
  RNLMsg := TRNLMessage.CreateFromBytes(Data);
  try
    FHost.BroadcastMessage(NET_CH_RELIABLE, RNLMsg);
  finally
    RNLMsg.DecRef;
  end;
end;

procedure TGameServer.BroadcastExcept(const Msg: TNetMessage; AExcludePlayerId: UInt32);
var
  i: Integer;
begin
  for i := 0 to High(FPeers) do
    if FPeers[i].Connected and (FPeers[i].PlayerId <> AExcludePlayerId) then
      SendTo(FPeers[i].Peer, Msg);
end;

procedure TGameServer.SetPeerEntityId(APeer: TRNLPeer; AEntityId: UInt32);
var
  Idx: Integer;
begin
  Idx := FindPeerIdx(APeer);
  if Idx <> -1 then
    FPeers[Idx].EntityId := AEntityId;
end;

function TGameServer.GetPeerEntityId(APeer: TRNLPeer): UInt32;
var
  Idx: Integer;
begin
  Idx := FindPeerIdx(APeer);
  if Idx <> -1 then
    Result := FPeers[Idx].EntityId
  else
    Result := 0;
end;

function TGameServer.GetPeerEntityIdByPlayerId(APlayerId: UInt32): UInt32;
var
  i: Integer;
begin
  for i := 0 to High(FPeers) do
    if FPeers[i].PlayerId = APlayerId then
      Exit(FPeers[i].EntityId);
  Result := 0;
end;

function TGameServer.FindPlayerIdByEntityId(AEntityId: UInt32): UInt32;
var
  i: Integer;
begin
  for i := 0 to High(FPeers) do
    if FPeers[i].EntityId = AEntityId then
      Exit(FPeers[i].PlayerId);
  Result := 0;
end;

end.
