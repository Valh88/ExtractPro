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

  TLobbyNetSystem = class(TLobbySystemBase)
  private
    FServer: TGameServer;
    FRpc: TRpcServer;
    FPort: Word;
    FMaxPlayers: Integer;
    FRequireAuth: Boolean;
    FPendingAuth: array of TPendingAuth;
    procedure OnPlayerConnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
    procedure OnPlayerDisconnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
    procedure OnPlayerReceive(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32; const Msg: TNetMessage);
    function FindPendingAuth(Peer: TRNLPeer): Integer;
  public
    constructor Create(ALobbyWorld: TLobbyWorldBase; APort: Word; AMaxPlayers: Integer = 64);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    procedure StartServer;
    procedure StopServer;
    function SendTo(Peer: TRNLPeer; const M: TNetMessage): Boolean;
    property Rpc: TRpcServer read FRpc;
    property RequireAuth: Boolean read FRequireAuth write FRequireAuth;
  end;

implementation

{ TLobbyNetSystem }

constructor TLobbyNetSystem.Create(ALobbyWorld: TLobbyWorldBase; APort: Word; AMaxPlayers: Integer);
begin
  inherited Create(ALobbyWorld);
  FPort := APort;
  FMaxPlayers := AMaxPlayers;
  FRequireAuth := False;
  FPendingAuth := nil;
  FServer := TGameServer.Create(FPort, FMaxPlayers);
  FServer.OnConnect := @OnPlayerConnected;
  FServer.OnDisconnect := @OnPlayerDisconnected;
  FServer.OnReceive := @OnPlayerReceive;
  FRpc := TRpcServer.Create;
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

function TLobbyNetSystem.FindPendingAuth(Peer: TRNLPeer): Integer;
begin
  for Result := 0 to High(FPendingAuth) do
    if FPendingAuth[Result].Peer = Peer then
      Exit;
  Result := -1;
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
  end;
end;

end.
