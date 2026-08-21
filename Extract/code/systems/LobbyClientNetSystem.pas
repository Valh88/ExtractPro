unit LobbyClientNetSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  CastleLog,
  LobbySystemBase, LobbyWorld,
  RNL, NetMessages, NetClient, RpcClient,
  ClientEventBus;

type
  TLobbyClientNetSystem = class(TLobbySystemBase)
  private
    FClient: TGameClient;
    FRpc: TRpcClient;
    FHost: string;
    FPort: Word;
    FAuthToken: string;
    FConnected: Boolean;
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
    function IsConnected: Boolean;

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

function TLobbyClientNetSystem.IsConnected: Boolean;
begin
  Result := FClient.State = csConnected;
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
  WritelnLog('LobbyNet', 'Connected to lobby server');
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
var
  E: TClientGameEvent;
  i, Count: Integer;
  PlayerId: UInt32;
  Ready: Byte;
  S: string;
  Payload: TReadyCheckUpdatePayload;
  StartPayload: TStartGamePayload;
begin
  case Msg.Header.MsgType of
    msgRpcResponse:
    begin
      if FRpc <> nil then
        FRpc.DispatchResponse(Msg.Header.CorrelationId, Msg.Payload);
    end;
    msgReadyCheck:
    begin
      WritelnLog('Client', 'Received msgReadyCheck — match found, waiting for ready confirmation');
      E.EventType := cgeReadyCheck;
      E.Amount := 1.0;
      GlobalClientEventBus.Queue(E);
      GlobalClientEventBus.Flush;
    end;
    msgReadyCheckUpdate:
    begin
      if Length(Msg.Payload) >= 1 then
      begin
        Count := Msg.Payload[0];
        S := '[Client] Ready status: ';
        Payload := TReadyCheckUpdatePayload.Create;
        SetLength(Payload.Players, Count);
        for i := 0 to Count - 1 do
        begin
          if 1 + i * 5 + 4 > Length(Msg.Payload) then Break;
          Payload.Players[i].PlayerId := Msg.Payload[1 + i * 5] or
                                        (Msg.Payload[2 + i * 5] shl 8) or
                                        (Msg.Payload[3 + i * 5] shl 16) or
                                        (Msg.Payload[4 + i * 5] shl 24);
          Payload.Players[i].Ready := Msg.Payload[5 + i * 5] = 1;
          S := S + Format('[%d:%s] ', [Payload.Players[i].PlayerId,
            BoolToStr(Payload.Players[i].Ready, True)]);
        end;
        WritelnLog('Client', '%s', [S]);
        E.EventType := cgeReadyCheckUpdate;
        E.Amount := 0.0;
        E.Data := Payload;
        GlobalClientEventBus.Queue(E);
        GlobalClientEventBus.Flush;
      end;
    end;
    msgReadyCheckEnd:
    begin
      if Length(Msg.Payload) >= 1 then
      begin
        case Msg.Payload[0] of
          0: WritelnLog('Client', 'Ready check failed (timeout), back to queue');
          1: WritelnLog('Client', 'Ready check passed, game starting');
          2: WritelnLog('Client', 'Match cancelled, re-enqueued');
        end;
      end;
      if (Length(Msg.Payload) >= 1) and (Msg.Payload[0] = 2) then
      begin
        E.EventType := cgeReadyCheck;
        E.Amount := 2.0;
        GlobalClientEventBus.Queue(E);
        GlobalClientEventBus.Flush;
      end else
      if (Length(Msg.Payload) >= 1) and (Msg.Payload[0] = 0) then
      begin
        E.EventType := cgeReadyCheck;
        E.Amount := 0.0;
        GlobalClientEventBus.Queue(E);
        GlobalClientEventBus.Flush;
      end;
    end;
    msgStartGame:
    begin
      if Length(Msg.Payload) >= 10 then
      begin
        StartPayload := TStartGamePayload.Create;
        StartPayload.Port := Msg.Payload[0] or (Msg.Payload[1] shl 8);
        StartPayload.LobbyId := Msg.Payload[2] or (Msg.Payload[3] shl 8)
          or (Msg.Payload[4] shl 16) or (Msg.Payload[5] shl 24);
        StartPayload.PlayerId := Msg.Payload[6] or (Msg.Payload[7] shl 8)
          or (Msg.Payload[8] shl 16) or (Msg.Payload[9] shl 24);
        E.EventType := cgeStartGame;
        E.Amount := StartPayload.Port;
        E.Data := StartPayload;
        GlobalClientEventBus.Queue(E);
        GlobalClientEventBus.Flush;
      end;
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
