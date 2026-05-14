{
  NetClient.pas — обёртка RNL-клиента.

  ── Состояния ──────────────────────────────────────────────────────
    csDisconnected   — нет соединения (начальное)
    csConnecting     — попытка подключиться (после Connect)
    csConnected      — соединение установлено (после OnConnected)
    csDisconnecting  — разрыв соединения

  ── Использование ──────────────────────────────────────────────────
    Client := TGameClient.Create;
    Client.OnConnected := @OnConnected;
    Client.OnReceive := @OnMessage;
    Client.Connect('127.0.0.1', 7777);

    // в игровом цикле:
    while True do begin
      Client.Service(0);
      // ... рендер / физика
    end;

    // отправка ввода:
    var M: TNetMessage;
    M.Init(msgInput, [Byte(MoveX), Byte(MoveY)]);
    Client.Send(M);

    // получение:
    Client.OnReceive := procedure(Sender: TObject; const Msg: TNetMessage)
    begin
      case Msg.Header.MsgType of
        msgSnapshot: // применить снапшот мира
        msgChat:     // показать в UI
      end;
    end;

  ── Зависимости ────────────────────────────────────────────────────
    RNL, NetMessages
}
unit NetClient;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  RNL,
  NetMessages;

type
  TClientState = (csDisconnected, csConnecting, csConnected, csDisconnecting);

  TClientConnectEvent = procedure(Sender: TObject) of object;
  TClientDisconnectEvent = procedure(Sender: TObject) of object;
  TClientReceiveEvent = procedure(Sender: TObject; const Msg: TNetMessage) of object;

  TGameClient = class
  private
    FInstance: TRNLInstance;
    FNetwork: TRNLRealNetwork;
    FHost: TRNLHost;
    FPeer: TRNLPeer;
    FState: TClientState;
    FHostAddr: String;
    FPort: Word;
    FEvent: TRNLHostEvent;
    FOnConnected: TClientConnectEvent;
    FOnDisconnected: TClientDisconnectEvent;
    FOnReceive: TClientReceiveEvent;
    procedure ClearEvent;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Connect(const AHost: String; APort: Word);
    procedure Disconnect;
    procedure Service(ATimeoutMs: Integer = 0);
    function Send(const Msg: TNetMessage): Boolean;
    property Peer: TRNLPeer read FPeer;
    property State: TClientState read FState;
    property OnConnected: TClientConnectEvent read FOnConnected write FOnConnected;
    property OnDisconnected: TClientDisconnectEvent read FOnDisconnected write FOnDisconnected;
    property OnReceive: TClientReceiveEvent read FOnReceive write FOnReceive;
  end;

implementation

{ TGameClient }

constructor TGameClient.Create;
begin
  inherited Create;
  FState := csDisconnected;
  FInstance := TRNLInstance.Create;
  FNetwork := TRNLRealNetwork.Create(FInstance);
  FHost := TRNLHost.Create(FInstance, FNetwork);
  FHost.MaximumCountPeers := 1;
  FHost.AllowIncomingConnections := False;
  FHost.ChannelTypes[0] := RNL_PEER_UNRELIABLE_UNORDERED_CHANNEL;
  FHost.ChannelTypes[1] := RNL_PEER_RELIABLE_ORDERED_CHANNEL;
  FHost.ProtocolID := $5472616e73477269;
  FEvent.Initialize;
end;

destructor TGameClient.Destroy;
begin
  Disconnect;
  FEvent.Free;
  FHost.Free;
  FNetwork.Free;
  FInstance.Free;
  inherited;
end;

procedure TGameClient.Connect(const AHost: String; APort: Word);
var
  Addr: TRNLAddress;
begin
  if FState <> csDisconnected then Exit;
  FHostAddr := AHost;
  FPort := APort;
  FHost.Start;
  Addr := TRNLAddress.CreateFromString(AHost + ':' + IntToStr(APort));
  FPeer := FHost.Connect(Addr, 2);
  if FPeer <> nil then
    FState := csConnecting;
end;

procedure TGameClient.Disconnect;
begin
  if FPeer <> nil then
  begin
    FPeer.Disconnect;
    FPeer := nil;
  end;
  FHost.Flush;
  FState := csDisconnected;
end;

procedure TGameClient.ClearEvent;
begin
  FEvent.Type_ := RNL_HOST_EVENT_TYPE_NONE;
  FEvent.Peer := nil;
  FEvent.Message := nil;
end;

procedure TGameClient.Service(ATimeoutMs: Integer);
var
  Status: TRNLHostServiceStatus;
  Msg: TNetMessage;
  Bytes: TBytes;
begin
  if FState = csDisconnected then Exit;

  ClearEvent;
  Status := FHost.Service(FEvent, ATimeoutMs);
  if Status <> RNL_HOST_SERVICE_STATUS_EVENT then Exit;

  case FEvent.Type_ of
    RNL_HOST_EVENT_TYPE_PEER_CONNECT:
    begin
      FState := csConnected;
      if Assigned(FOnConnected) then
        FOnConnected(Self);
    end;

    RNL_HOST_EVENT_TYPE_PEER_DISCONNECT:
    begin
      FPeer := nil;
      FState := csDisconnected;
      if Assigned(FOnDisconnected) then
        FOnDisconnected(Self);
    end;

    RNL_HOST_EVENT_TYPE_PEER_RECEIVE:
    begin
      if FEvent.Message = nil then Exit;
      Bytes := FEvent.Message.AsBytes;
      FEvent.Message.DecRef;
      FEvent.Message := nil;
      if TNetMessage.Unpack(Bytes, Msg) then
        if Assigned(FOnReceive) then
          FOnReceive(Self, Msg);
    end;
  end;
end;

function TGameClient.Send(const Msg: TNetMessage): Boolean;
var
  Data: TBytes;
  RNLMsg: TRNLMessage;
begin
  Result := False;
  if (FPeer = nil) or (FState <> csConnected) then Exit;
  Data := Msg.Pack;
  RNLMsg := TRNLMessage.CreateFromBytes(Data);
  try
    FPeer.Channels[NET_CH_RELIABLE].SendMessage(RNLMsg);
    Result := True;
  finally
    RNLMsg.DecRef;
  end;
end;

end.
