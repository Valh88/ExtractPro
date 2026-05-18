unit ClientNetSystem;

{$mode objfpc}{$H+}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes, WorldSystemBase, CastleKeysMouse,
  RNL, NetMessages, NetClient;

type
  TClientNetSystem = class(TWorldSystemBase)
  private
    FClient: TGameClient;
    FHost: string;
    FPort: Word;
    FMaxRetries: Integer;
    FRetryDelay: Single;
    FRetryCount: Integer;
    FRetryTimer: Single;
    FConnectTimer: Single;
    FWantDisconnect: Boolean;
    FConnected: Boolean;
    FLastError: string;
    function GetState: TClientState;
    function GetOnConnected: TClientConnectEvent;
    procedure SetOnConnected(const AValue: TClientConnectEvent);
    function GetOnDisconnected: TClientDisconnectEvent;
    procedure SetOnDisconnected(const AValue: TClientDisconnectEvent);
    function GetOnReceive: TClientReceiveEvent;
    procedure SetOnReceive(const AValue: TClientReceiveEvent);
    procedure OnClientConnected(Sender: TObject);
    procedure OnClientDisconnected(Sender: TObject);
    procedure OnClientReceive(Sender: TObject; const Msg: TNetMessage);
    procedure DoConnect;
  public
    constructor Create(AWorldObj: TObject; AMaxRetries: Integer = 3; ARetryDelay: Single = 2.0);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    procedure Connect(const AHost: string; APort: Word);
    procedure Disconnect;
    function Send(const Msg: TNetMessage): Boolean;
    property Client: TGameClient read FClient;
    property State: TClientState read GetState;
    property LastError: string read FLastError;
    property OnConnected: TClientConnectEvent read GetOnConnected write SetOnConnected;
    property OnDisconnected: TClientDisconnectEvent read GetOnDisconnected write SetOnDisconnected;
    property OnReceive: TClientReceiveEvent read GetOnReceive write SetOnReceive;
  end;

implementation

{ TClientNetSystem }

constructor TClientNetSystem.Create(AWorldObj: TObject; AMaxRetries: Integer; ARetryDelay: Single);
begin
  inherited Create(AWorldObj);
  FClient := nil;
  FMaxRetries := AMaxRetries;
  FRetryDelay := ARetryDelay;
  FRetryCount := 0;
  FRetryTimer := 0;
  FConnectTimer := 0;
  FWantDisconnect := False;
  FConnected := False;

  Connect('127.0.0.1', 7777);
end;

destructor TClientNetSystem.Destroy;
begin
  FConnected := False;
  FreeAndNil(FClient);
  inherited;
end;

procedure TClientNetSystem.Connect(const AHost: string; APort: Word);
begin
  FHost := AHost;
  FPort := APort;
  FRetryCount := 0;
  FRetryTimer := 0;
  FConnectTimer := 0;
  FWantDisconnect := False;
  FConnected := True;
  FLastError := '';
  DoConnect;
end;

procedure TClientNetSystem.Disconnect;
begin
  FWantDisconnect := True;
  FConnected := False;
  FRetryCount := FMaxRetries;
  FRetryTimer := 0;
  FConnectTimer := 0;
  FreeAndNil(FClient);
end;

procedure TClientNetSystem.DoConnect;
begin
  FreeAndNil(FClient);
  FClient := TGameClient.Create;
  FClient.OnConnected := @OnClientConnected;
  FClient.OnDisconnected := @OnClientDisconnected;
  FClient.OnReceive := @OnClientReceive;
  try
    FClient.Connect(FHost, FPort);
  except
    on E: Exception do
      FreeAndNil(FClient);
  end;
end;

function TClientNetSystem.Send(const Msg: TNetMessage): Boolean;
begin
  if FClient <> nil then
    Result := FClient.Send(Msg)
  else
    Result := False;
end;

procedure TClientNetSystem.Update(const SecondsPassed: Single);
begin
  if FClient = nil then Exit;

  if FClient.State <> csDisconnected then
    FClient.Service(50);

  if (FClient.State = csDisconnected) and FConnected and (FRetryCount < FMaxRetries) then
  begin
    FRetryTimer := FRetryTimer + SecondsPassed;
    if FRetryTimer >= FRetryDelay then
    begin
      Inc(FRetryCount);
      FRetryTimer := 0;
      DoConnect;
    end;
  end;
end;

function TClientNetSystem.GetState: TClientState;
begin
  if FClient <> nil then
    Result := FClient.State
  else
    Result := csDisconnected;
end;

function TClientNetSystem.GetOnConnected: TClientConnectEvent;
begin
  if FClient <> nil then
    Result := FClient.OnConnected
  else
    Result := nil;
end;

procedure TClientNetSystem.SetOnConnected(const AValue: TClientConnectEvent);
begin
  if FClient <> nil then
    FClient.OnConnected := AValue;
end;

function TClientNetSystem.GetOnDisconnected: TClientDisconnectEvent;
begin
  if FClient <> nil then
    Result := FClient.OnDisconnected
  else
    Result := nil;
end;

procedure TClientNetSystem.SetOnDisconnected(const AValue: TClientDisconnectEvent);
begin
  if FClient <> nil then
    FClient.OnDisconnected := AValue;
end;

function TClientNetSystem.GetOnReceive: TClientReceiveEvent;
begin
  if FClient <> nil then
    Result := FClient.OnReceive
  else
    Result := nil;
end;

procedure TClientNetSystem.SetOnReceive(const AValue: TClientReceiveEvent);
begin
  if FClient <> nil then
    FClient.OnReceive := AValue;
end;

procedure TClientNetSystem.OnClientConnected(Sender: TObject);
begin
  FRetryCount := 0;
  FRetryTimer := 0;
  FLastError := '';
end;

procedure TClientNetSystem.OnClientDisconnected(Sender: TObject);
begin
  if not FWantDisconnect then
  begin
    if FRetryCount < FMaxRetries then
      FLastError := 'Connection lost. Retrying...'
    else
      FLastError := 'Connection lost. Max retries reached.';
  end;
end;

procedure TClientNetSystem.OnClientReceive(Sender: TObject; const Msg: TNetMessage);
begin
end;

end.
