unit LobbyManagerSystem;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  CastleKeysMouse, Interfaces, LobbyManager;

type
  TLobbyManagerSystem = class(TInterfacedObject, IWorldSystem)
  private
    FManager: TLobbyManager;
  public
    constructor Create(AManager: TLobbyManager);
    procedure Update(const SecondsPassed: Single);
    function Press(const Event: TInputPressRelease): Boolean;
    property Manager: TLobbyManager read FManager;
  end;

implementation

{ TLobbyManagerSystem }

constructor TLobbyManagerSystem.Create(AManager: TLobbyManager);
begin
  inherited Create;
  FManager := AManager;
end;

procedure TLobbyManagerSystem.Update(const SecondsPassed: Single);
begin
end;

function TLobbyManagerSystem.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := False;
end;

end.
