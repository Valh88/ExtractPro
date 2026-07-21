unit LobbyClientNetSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  LobbySystemBase, LobbyWorld,
  RNL, NetMessages, NetClient, RpcClient;

type
  TLobbyClientNetSystem = class(TLobbySystemBase)
  private
    FClient: TGameClient;
    FRpc: TRpcClient;
    FHost: string;
    FPort: Word;
    FAuthToken: string;
    FOnConnected: TNotifyEvent;
    FOnDisconnected: TNotifyEvent;
    FOnRoomList: TNotifyEvent;
    FOnJoinAccepted: TNotifyEvent;
    FOnJoinDenied: TNotifyEvent;
    procedure HandleConnected(Sender: TObject);
    procedure HandleDisconnected(Sender: TObject);
    procedure OnReceive(Sender: TObject; const Msg: TNetMessage);
  public
    constructor Create(ALobbyWorld: TLobbyWorldBase);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    procedure Connect(const AHost: string; APort: Word);
    procedure Disconnect;
    procedure Send(const M: TNetMessage; const AChannel: Byte = NET_CH_RELIABLE);
    procedure RequestRoomList;
    procedure RequestJoinRaid(const ARoomId: UInt32);

    property AuthToken: string read FAuthToken write FAuthToken;
    property Rpc: TRpcClient read FRpc write FRpc;
    property OnConnected: TNotifyEvent read FOnConnected write FOnConnected;
    property OnDisconnected: TNotifyEvent read FOnDisconnected write FOnDisconnected;
    property OnRoomList: TNotifyEvent read FOnRoomList write FOnRoomList;
    property OnJoinAccepted: TNotifyEvent read FOnJoinAccepted write FOnJoinAccepted;
    property OnJoinDenied: TNotifyEvent read FOnJoinDenied write FOnJoinDenied;
  end;

implementation

{ TLobbyClientNetSystem }

constructor TLobbyClientNetSystem.Create(ALobbyWorld: TLobbyWorldBase);
begin
  inherited Create(ALobbyWorld);
  FClient := TGameClient.Create;
  FClient.OnConnected := @HandleConnected;
  FClient.OnDisconnected := @HandleDisconnected;
  FClient.OnReceive := @OnReceive;
end;

destructor TLobbyClientNetSystem.Destroy;
begin
  FClient.Free;
  inherited;
end;

procedure TLobbyClientNetSystem.Connect(const AHost: string; APort: Word);
begin
  FHost := AHost;
  FPort := APort;
  FClient.Connect(AHost, APort);
end;

procedure TLobbyClientNetSystem.Disconnect;
begin
  FClient.Disconnect;
end;

procedure TLobbyClientNetSystem.Send(const M: TNetMessage; const AChannel: Byte);
begin
  FClient.Send(M, AChannel);
end;

procedure TLobbyClientNetSystem.Update(const SecondsPassed: Single);
begin
  if FClient.State <> csDisconnected then
    FClient.Service;
end;

procedure TLobbyClientNetSystem.HandleConnected(Sender: TObject);
var
  M: TNetMessage;
  AuthData: TAuthPayload;
  i: Integer;
begin
  WriteLn(StdErr, '[LobbyNet] Connected to lobby server');
  if FAuthToken <> '' then
  begin
    FillChar(AuthData, SizeOf(AuthData), 0);
    for i := 1 to Length(FAuthToken) do
      if i <= 64 then
        AuthData.Token[i - 1] := AnsiChar(FAuthToken[i]);
    M.Init(msgAuth, AuthData.ToBytes);
    FClient.Send(M, NET_CH_RELIABLE);
  end;
  if Assigned(FOnConnected) then
    FOnConnected(Self);
end;

procedure TLobbyClientNetSystem.HandleDisconnected(Sender: TObject);
begin
  if Assigned(FOnDisconnected) then
    FOnDisconnected(Self);
end;

procedure TLobbyClientNetSystem.OnReceive(Sender: TObject; const Msg: TNetMessage);
begin
  case Msg.Header.MsgType of
    msgRpcResponse:
    begin
      if FRpc <> nil then
        FRpc.DispatchResponse(Msg.Header.CorrelationId, Msg.Payload);
    end;
    msgReadyCheck:
    begin
      WriteLn(StdErr, '[Client] Received msgReadyCheck — match found, waiting for ready confirmation');
    end;
  end;
end;

procedure TLobbyClientNetSystem.RequestRoomList;
var
  M: TNetMessage;
begin
  M.Init(msgRoomListRequest);
  FClient.Send(M, NET_CH_RELIABLE);
end;

procedure TLobbyClientNetSystem.RequestJoinRaid(const ARoomId: UInt32);
var
  M: TNetMessage;
begin
  M.Init(msgJoinRaid, [Byte(ARoomId), Byte(ARoomId shr 8),
    Byte(ARoomId shr 16), Byte(ARoomId shr 24)]);
  FClient.Send(M, NET_CH_RELIABLE);
end;

end.
