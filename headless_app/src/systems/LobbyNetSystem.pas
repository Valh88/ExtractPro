unit LobbyNetSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  LobbySystemBase, LobbyWorld,
  RNL, NetMessages, NetServer;

type
  TLobbyNetSystem = class(TLobbySystemBase)
  private
    FServer: TGameServer;
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
end;

destructor TLobbyNetSystem.Destroy;
begin
  StopServer;
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
