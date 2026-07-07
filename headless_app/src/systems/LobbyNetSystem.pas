unit LobbyNetSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  LobbySystemBase, LobbyWorld,
  RNL, NetMessages, NetServer, RpcServer, RpcTypes;

type
  TLobbyNetSystem = class(TLobbySystemBase)
  private
    FServer: TGameServer;
    FRpc: TRpcServer;
    FPort: Word;
    FMaxPlayers: Integer;
    procedure OnPlayerConnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
    procedure OnPlayerDisconnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
    procedure OnPlayerReceive(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32; const Msg: TNetMessage);
  public
    constructor Create(ALobbyWorld: TLobbyWorldBase; APort: Word; AMaxPlayers: Integer = 64);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    procedure StartServer;
    procedure StopServer;
    function SendTo(Peer: TRNLPeer; const M: TNetMessage): Boolean;
    property Rpc: TRpcServer read FRpc;
  end;

implementation

{ TLobbyNetSystem }

constructor TLobbyNetSystem.Create(ALobbyWorld: TLobbyWorldBase; APort: Word; AMaxPlayers: Integer);
begin
  inherited Create(ALobbyWorld);
  FPort := APort;
  FMaxPlayers := AMaxPlayers;
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

procedure TLobbyNetSystem.Update(const SecondsPassed: Single);
begin
  FServer.Service(0);
end;

procedure TLobbyNetSystem.OnPlayerConnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
begin
  // TODO: add to LobbyWorld.Players, send room list
end;

procedure TLobbyNetSystem.OnPlayerDisconnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
begin
  // TODO: remove from LobbyWorld.Players
end;

procedure TLobbyNetSystem.OnPlayerReceive(Sender: TObject; Peer: TRNLPeer;
  PlayerId: UInt32; const Msg: TNetMessage);
begin
  // TODO: handle msgRoomListRequest, msgJoinRaid, msgChat
end;

end.
