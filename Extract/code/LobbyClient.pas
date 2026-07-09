unit LobbyClient;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes,
  LobbyWorld, help_types, Interfaces,
  LobbyClientNetSystem, ClientAuthSystem, RpcClient, NetMessages;

type
  TLobbyClient = class(TLobbyWorldBase)
  private
    FAuthSystem: TClientAuthSystem;
    FRpc: TRpcClient;
    FNetSystem: TLobbyClientNetSystem;
  protected
    procedure RegisterSystems; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Connect(const AHost: string; APort: Word);
    procedure Disconnect;
    property AuthSystem: TClientAuthSystem read FAuthSystem;
    property Rpc: TRpcClient read FRpc;
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
  FRpc.Free;
  inherited;
end;

procedure TLobbyClient.RegisterSystems;
begin
  inherited;
  FRpc := TRpcClient.Create;
  FRpc.SendProc := procedure(const M: TNetMessage)
  begin
    FNetSystem.Send(M);
  end;
  FAuthSystem := TClientAuthSystem.Create;
  AddSystem(FAuthSystem);
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
