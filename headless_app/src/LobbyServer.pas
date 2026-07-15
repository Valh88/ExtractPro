unit LobbyServer;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  LobbyWorld, help_types, Interfaces,
  LobbyNetSystem, ServerDbSystem, LobbyManager;

type
  TLobbyServer = class(TLobbyWorldBase)
  private
    FNetSystem: TLobbyNetSystem;
    FDbSystem: TServerDbSystem;
    FPort: Word;
    FMaxPlayers: Integer;
    function GetRequireAuth: Boolean;
    function GetLobbyManager: TLobbyManager;
    procedure SetRequireAuth(const AValue: Boolean);
  protected
    procedure RegisterSystems; override;
  public
    constructor Create(APort: Word; AMaxPlayers: Integer = 64);
    destructor Destroy; override;
    procedure AddSystem(ASystem: IWorldSystem);
    procedure SetDbSystem(aDbSystem: TServerDbSystem);
    procedure Start; override;
    procedure Stop; override;
    property RequireAuth: Boolean read GetRequireAuth write SetRequireAuth;
    property LobbyManager: TLobbyManager read GetLobbyManager;
  end;

implementation

uses LobbyManagerSystem;

{ TLobbyServer }

constructor TLobbyServer.Create(APort: Word; AMaxPlayers: Integer);
begin
  FPort := APort;
  FMaxPlayers := AMaxPlayers;
  inherited Create;
end;

destructor TLobbyServer.Destroy;
begin
  inherited;
end;

procedure TLobbyServer.AddSystem(ASystem: IWorldSystem);
begin
  FSystems.Add(ASystem);
end;

procedure TLobbyServer.SetDbSystem(aDbSystem: TServerDbSystem);
begin
  FDbSystem := aDbSystem;
  if aDbSystem <> nil then
    AddSystem(aDbSystem);
end;

function TLobbyServer.GetLobbyManager: TLobbyManager;
var
  I: Integer;
  S: IWorldSystem;
  Obj: TObject;
begin
  for I := 0 to FSystems.Count - 1 do
  begin
    S := FSystems[I];
    Obj := TObject(Pointer(S));
    if Obj is TLobbyManagerSystem then
      Exit(TLobbyManagerSystem(Obj).Manager);
  end;
  Result := nil;
end;

procedure TLobbyServer.RegisterSystems;
begin
  inherited;
  FNetSystem := TLobbyNetSystem.Create(Self, FPort, FMaxPlayers);
  AddSystem(FNetSystem);
end;

procedure TLobbyServer.Start;
begin
  FNetSystem.StartServer;
  inherited;
end;

procedure TLobbyServer.Stop;
begin
  inherited;
  FNetSystem.StopServer;
end;

function TLobbyServer.GetRequireAuth: Boolean;
begin
  if FNetSystem <> nil then
    Result := FNetSystem.RequireAuth
  else
    Result := False;
end;

procedure TLobbyServer.SetRequireAuth(const AValue: Boolean);
begin
  if FNetSystem <> nil then
    FNetSystem.RequireAuth := AValue;
end;

end.
