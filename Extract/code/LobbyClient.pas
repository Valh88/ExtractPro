unit LobbyClient;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  LobbyWorld, help_types, Interfaces,
  LobbyClientNetSystem;

type
  TLobbyClient = class(TLobbyWorldBase)
  private
    FNetSystem: TLobbyClientNetSystem;
  protected
    procedure RegisterSystems; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Connect(const AHost: string; APort: Word);
    procedure Disconnect;
    property NetSystem: TLobbyClientNetSystem read FNetSystem;
  end;

implementation

{ TLobbyClient }

constructor TLobbyClient.Create;
begin
  inherited Create;
end;

destructor TLobbyClient.Destroy;
begin
  inherited;
end;

procedure TLobbyClient.RegisterSystems;
begin
  inherited;
  FNetSystem := TLobbyClientNetSystem.Create(Self);
  AddSystem(FNetSystem);
end;

procedure TLobbyClient.Connect(const AHost: string; APort: Word);
begin
  FNetSystem.Connect(AHost, APort);
end;

procedure TLobbyClient.Disconnect;
begin
  FNetSystem.Disconnect;
end;

end.
