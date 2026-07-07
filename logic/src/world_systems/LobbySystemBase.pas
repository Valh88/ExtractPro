unit LobbySystemBase;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Interfaces, CastleKeysMouse,
  LobbyWorld;

type
  TLobbySystemBase = class(TInterfacedObject, IWorldSystem)
  private
    FLobbyWorld: TLobbyWorldBase;
  public
    constructor Create(ALobbyWorld: TLobbyWorldBase);
    property LobbyWorld: TLobbyWorldBase read FLobbyWorld;
    procedure Update(const SecondsPassed: Single); virtual; abstract;
    function Press(const Event: TInputPressRelease): Boolean; virtual;
  end;

implementation

constructor TLobbySystemBase.Create(ALobbyWorld: TLobbyWorldBase);
begin
  inherited Create;
  FLobbyWorld := ALobbyWorld;
end;

function TLobbySystemBase.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := False;
end;

end.
