unit LobbyNetSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  LobbySystemBase, LobbyWorld,
  RNL, NetMessages, NetServer, RpcServer, RpcTypes, AuthTypes;

type
  TPendingAuth = record
    Peer: TRNLPeer;
    PlayerId: UInt32;
    Timeout: Single;
  end;

  TRpcCallerInfo = record
    CorrelationId: TGuid;
    Peer: TRNLPeer;
    PlayerId: UInt32;
  end;

  TLobbyNetSystem = class(TLobbySystemBase)
  private
    FServer: TGameServer;
    FRpc: TRpcServer;
    FPort: Word;
    FMaxPlayers: Integer;
    FRequireAuth: Boolean;
    FPendingAuth: array of TPendingAuth;
    FRpcCallers: array of TRpcCallerInfo;
    FManagerSystem: TObject;

    procedure OnPlayerConnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
    procedure OnPlayerDisconnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
    procedure OnPlayerReceive(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32; const Msg: TNetMessage);
    function FindPendingAuth(Peer: TRNLPeer): Integer;
    procedure HandleRpcRequest(Peer: TRNLPeer; PlayerId: UInt32; const Msg: TNetMessage);
    function FindRpcCaller(const ACorrId: TGuid): Integer;
    procedure RemoveRpcCaller(const ACorrId: TGuid);
    procedure HandleRpcQueueJoin(const RequestPayload: TBytes;
      const CorrelationId: TGuid; const ReplyProc: TRpcReplyProc);
    procedure HandleRpcQueueLeave(const RequestPayload: TBytes;
      const CorrelationId: TGuid; const ReplyProc: TRpcReplyProc);
  public
    constructor Create(ALobbyWorld: TLobbyWorldBase; APort: Word; AMaxPlayers: Integer = 64);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    procedure StartServer;
    procedure StopServer;
    function SendTo(Peer: TRNLPeer; const M: TNetMessage): Boolean;
    function SendToPlayer(APlayerId: UInt32; const M: TNetMessage): Boolean;
    property Rpc: TRpcServer read FRpc;
    property RequireAuth: Boolean read FRequireAuth write FRequireAuth;
    property ManagerSystem: TObject read FManagerSystem write FManagerSystem;
  end;

implementation

uses LobbyManagerSystem, MatchmakingSM;

type
  TRpcReplyCtx = class
    Peer: TRNLPeer;
    CorrelationId: TGuid;
    Net: TLobbyNetSystem;
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

{ TLobbyNetSystem }

constructor TLobbyNetSystem.Create(ALobbyWorld: TLobbyWorldBase; APort: Word; AMaxPlayers: Integer);
begin
  inherited Create(ALobbyWorld);
  FPort := APort;
  FMaxPlayers := AMaxPlayers;
  FRequireAuth := False;
  FPendingAuth := nil;
  FRpcCallers := nil;
  FServer := TGameServer.Create(FPort, FMaxPlayers);
  FServer.OnConnect := @OnPlayerConnected;
  FServer.OnDisconnect := @OnPlayerDisconnected;
  FServer.OnReceive := @OnPlayerReceive;
  FRpc := TRpcServer.Create;
  FRpc.RegisterHandler(rpcQueueJoin, @HandleRpcQueueJoin);
  FRpc.RegisterHandler(rpcQueueLeave, @HandleRpcQueueLeave);
end;

destructor TLobbyNetSystem.Destroy;
begin
  StopServer;
  FRpc.Free;
  FServer.Free;
  inherited;
end;

procedure TLobbyNetSystem.StartServer;
begin
  FServer.Start;
end;

procedure TLobbyNetSystem.StopServer;
begin
  FServer.Stop;
end;

function TLobbyNetSystem.SendTo(Peer: TRNLPeer; const M: TNetMessage): Boolean;
begin
  Result := FServer.SendTo(Peer, M);
end;

function TLobbyNetSystem.SendToPlayer(APlayerId: UInt32; const M: TNetMessage): Boolean;
begin
  Result := FServer.SendToPlayer(APlayerId, M);
end;

function TLobbyNetSystem.FindPendingAuth(Peer: TRNLPeer): Integer;
begin
  for Result := 0 to High(FPendingAuth) do
    if FPendingAuth[Result].Peer = Peer then
      Exit;
  Result := -1;
end;

function TLobbyNetSystem.FindRpcCaller(const ACorrId: TGuid): Integer;
begin
  for Result := 0 to High(FRpcCallers) do
    if FRpcCallers[Result].CorrelationId = ACorrId then
      Exit;
  Result := -1;
end;

procedure TLobbyNetSystem.RemoveRpcCaller(const ACorrId: TGuid);
var
  Idx, Last: Integer;
begin
  Idx := FindRpcCaller(ACorrId);
  if Idx < 0 then Exit;
  Last := High(FRpcCallers);
  if Idx < Last then
    FRpcCallers[Idx] := FRpcCallers[Last];
  SetLength(FRpcCallers, Last);
end;

procedure TLobbyNetSystem.HandleRpcRequest(Peer: TRNLPeer; PlayerId: UInt32; const Msg: TNetMessage);
var
  Ctx: TRpcReplyCtx;
  L: Integer;
begin
  if Length(Msg.Payload) < 1 then Exit;

  L := Length(FRpcCallers);
  SetLength(FRpcCallers, L + 1);
  FRpcCallers[L].CorrelationId := Msg.Header.CorrelationId;
  FRpcCallers[L].Peer := Peer;
  FRpcCallers[L].PlayerId := PlayerId;

  Ctx := TRpcReplyCtx.Create;
  Ctx.Net := Self;
  Ctx.Peer := Peer;
  Ctx.CorrelationId := Msg.Header.CorrelationId;
  if not FRpc.DispatchRequest(Msg.Payload[0],
    Copy(Msg.Payload, 1, Length(Msg.Payload) - 1),
    Msg.Header.CorrelationId, @Ctx.Reply) then
  begin
    Ctx.Free;
    RemoveRpcCaller(Msg.Header.CorrelationId);
  end;
  // if dispatched, caller info is kept until handler removes it
end;

procedure TLobbyNetSystem.HandleRpcQueueJoin(const RequestPayload: TBytes;
  const CorrelationId: TGuid; const ReplyProc: TRpcReplyProc);
var
  Idx, PIdx: Integer;
  Mgr: TLobbyManagerSystem;
  Q: TQueuedPlayerArray;
  i: Integer;
begin
  Idx := FindRpcCaller(CorrelationId);
  if Idx < 0 then Exit;

  Mgr := TLobbyManagerSystem(FManagerSystem);
  if Mgr = nil then
  begin
    RemoveRpcCaller(CorrelationId);
    Exit;
  end;

  PIdx := LobbyWorld.FindPlayerIndex(FRpcCallers[Idx].PlayerId);
  if PIdx >= 0 then
  begin
    Mgr.EnqueuePlayer(FRpcCallers[Idx].PlayerId,
      LobbyWorld.Players[PIdx].Login, 1);
    WriteLn(StdErr, '[LobbyServer] Player ', FRpcCallers[Idx].PlayerId,
      ' (', LobbyWorld.Players[PIdx].Login, ') joined queue');
  end;

  Q := Mgr.GetQueue;
  Write(StdErr, '[LobbyServer] Queue [');
  for i := 0 to High(Q) do
  begin
    if i > 0 then Write(StdErr, ', ');
    Write(StdErr, Q[i].PlayerId, ':', Q[i].Login);
  end;
  WriteLn(StdErr, '] (', Length(Q), '/', Mgr.GetPartiesPerMatch, ')');

  RemoveRpcCaller(CorrelationId);
  ReplyProc(nil);
end;

procedure TLobbyNetSystem.HandleRpcQueueLeave(const RequestPayload: TBytes;
  const CorrelationId: TGuid; const ReplyProc: TRpcReplyProc);
var
  Idx: Integer;
  Mgr: TLobbyManagerSystem;
  Q: TQueuedPlayerArray;
  i: Integer;
begin
  Idx := FindRpcCaller(CorrelationId);
  if Idx < 0 then Exit;

  Mgr := TLobbyManagerSystem(FManagerSystem);
  if Mgr <> nil then
  begin
    Mgr.DequeuePlayer(FRpcCallers[Idx].PlayerId);
    WriteLn(StdErr, '[LobbyServer] Player ', FRpcCallers[Idx].PlayerId, ' left queue');
    Q := Mgr.GetQueue;
    Write(StdErr, '[LobbyServer] Queue [');
    for i := 0 to High(Q) do
    begin
      if i > 0 then Write(StdErr, ', ');
      Write(StdErr, Q[i].PlayerId, ':', Q[i].Login);
    end;
    WriteLn(StdErr, '] (', Length(Q), '/', Mgr.GetPartiesPerMatch, ')');
  end;

  RemoveRpcCaller(CorrelationId);
  ReplyProc(nil);
end;

procedure TLobbyNetSystem.Update(const SecondsPassed: Single);
var
  i: Integer;
  M: TNetMessage;
begin
  FServer.Service(0);
  i := 0;
  while i < Length(FPendingAuth) do
  begin
    FPendingAuth[i].Timeout := FPendingAuth[i].Timeout - SecondsPassed;
    if FPendingAuth[i].Timeout <= 0 then
    begin
      WriteLn(StdErr, '[LobbyServer] Auth timeout for player ', FPendingAuth[i].PlayerId);
      M.Init(msgJoinDeny, [Byte(Ord('T')), Byte(Ord('O'))]);
      SendTo(FPendingAuth[i].Peer, M);
      FPendingAuth[i].Peer.Disconnect;
      FPendingAuth[i] := FPendingAuth[High(FPendingAuth)];
      SetLength(FPendingAuth, Length(FPendingAuth) - 1);
    end
    else
      Inc(i);
  end;
end;

procedure TLobbyNetSystem.OnPlayerConnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
var
  L: Integer;
begin
  WriteLn(StdErr, '[LobbyServer] Player connected: id=', PlayerId);
  if not FRequireAuth then
    LobbyWorld.AddPlayer(PlayerId, '')
  else
  begin
    L := Length(FPendingAuth);
    SetLength(FPendingAuth, L + 1);
    FPendingAuth[L].Peer := Peer;
    FPendingAuth[L].PlayerId := PlayerId;
    FPendingAuth[L].Timeout := 10;
  end;
end;

procedure TLobbyNetSystem.OnPlayerDisconnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
var
  Idx: Integer;
begin
  Idx := FindPendingAuth(Peer);
  if Idx <> -1 then
  begin
    FPendingAuth[Idx] := FPendingAuth[High(FPendingAuth)];
    SetLength(FPendingAuth, Length(FPendingAuth) - 1);
  end
  else
    LobbyWorld.RemovePlayer(PlayerId);
end;

procedure TLobbyNetSystem.OnPlayerReceive(Sender: TObject; Peer: TRNLPeer;
  PlayerId: UInt32; const Msg: TNetMessage);
var
  AuthData: TAuthPayload;
  AuthToken: string;
  AuthResult: TAuthResult;
  M: TNetMessage;
  Idx: Integer;
begin
  case Msg.Header.MsgType of
    msgAuth:
    begin
      if not (FRequireAuth and (LobbyWorld.AuthValidator <> nil)) then
        Exit;
      if TAuthPayload.FromBytes(Msg.Payload, AuthData) then
      begin
        AuthToken := TrimRight(string(AuthData.Token));
        AuthResult := LobbyWorld.AuthValidator.ValidateToken(AuthToken);
        if AuthResult.Valid then
        begin
          Idx := FindPendingAuth(Peer);
          if Idx <> -1 then
          begin
            LobbyWorld.AddPlayer(FPendingAuth[Idx].PlayerId, AuthResult.Login);
            FPendingAuth[Idx] := FPendingAuth[High(FPendingAuth)];
            SetLength(FPendingAuth, Length(FPendingAuth) - 1);
          end;
          WriteLn(StdErr, '[LobbyServer] Player ', PlayerId, ' authenticated as ', AuthResult.Login);
        end
        else
        begin
          WriteLn(StdErr, '[LobbyServer] Auth failed for player ', PlayerId);
          M.Init(msgJoinDeny, [Byte(Ord('A')), Byte(Ord('U')), Byte(Ord('T'))]);
          SendTo(Peer, M);
          Peer.Disconnect;
        end;
      end;
    end;
    msgRoomListRequest:
    begin
      // TODO: send room list
    end;
    msgJoinRaid:
    begin
      // TODO: handle join raid request
    end;
    msgRpcRequest:
    begin
      HandleRpcRequest(Peer, PlayerId, Msg);
    end;
  end;
end;

end.
