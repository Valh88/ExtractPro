unit LobbyServer;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  LobbyWorld, help_types, Interfaces,
  LobbyNetSystem, ServerDbSystem;

type
  TLobbyServer = class(TLobbyWorldBase)
  private
    FNetSystem: TLobbyNetSystem;
    FDbSystem: TServerDbSystem;
    FPort: Word;
    FMaxPlayers: Integer;
  protected
    procedure RegisterSystems; override;
  public
    constructor Create(APort: Word; AMaxPlayers: Integer = 64);
    destructor Destroy; override;
    procedure SetDbSystem(aDbSystem: TServerDbSystem);
    procedure Start; override;
    procedure Stop; override;
  end;

implementation

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

procedure TLobbyServer.SetDbSystem(aDbSystem: TServerDbSystem);
begin
  FDbSystem := aDbSystem;
  if aDbSystem <> nil then
    AddSystem(aDbSystem);
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

end.
