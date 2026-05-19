unit ServerNetSystem;

{$mode objfpc}{$H+}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes, WorldSystemBase, CastleKeysMouse,
  RNL, NetMessages, NetServer;

type
  TServerNetSystem = class(TWorldSystemBase)
  private
    FServer: TGameServer;
    function GetOnConnect: TServerConnectEvent;
    procedure SetOnConnect(const AValue: TServerConnectEvent);
    function GetOnDisconnect: TServerDisconnectEvent;
    procedure SetOnDisconnect(const AValue: TServerDisconnectEvent);
    function GetOnReceive: TServerReceiveEvent;
    procedure SetOnReceive(const AValue: TServerReceiveEvent);
  public
    constructor Create(AWorldObj: TObject; APort: Word; AMaxPlayers: Integer);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    procedure StartServer;
    procedure StopServer;
    function SendTo(APeer: TRNLPeer; const Msg: TNetMessage): Boolean;
    function SendToPlayer(APlayerId: UInt32; const Msg: TNetMessage): Boolean;
    procedure Broadcast(const Msg: TNetMessage);
    procedure BroadcastExcept(const Msg: TNetMessage; AExcludePlayerId: UInt32);
    procedure OnPlayerConnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
    property Server: TGameServer read FServer;
    property OnConnect: TServerConnectEvent read GetOnConnect write SetOnConnect;
    property OnDisconnect: TServerDisconnectEvent read GetOnDisconnect write SetOnDisconnect;
    property OnReceive: TServerReceiveEvent read GetOnReceive write SetOnReceive;
  end;

implementation

{ TServerNetSystem }

constructor TServerNetSystem.Create(AWorldObj: TObject; APort: Word; AMaxPlayers: Integer);
begin
  inherited Create(AWorldObj);
  FServer := TGameServer.Create(APort, AMaxPlayers);
  OnConnect := @OnPlayerConnected;
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

procedure TServerNetSystem.OnPlayerConnected(Sender: TObject; Peer: TRNLPeer; PlayerId: UInt32);
begin
  WriteLn('Player connected: ', PlayerId);
end;

end.
