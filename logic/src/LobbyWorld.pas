unit LobbyWorld;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Generics.Collections, help_types, GameConfig, Interfaces,
  AuthTypes, CastleKeysMouse;

type
  TLobbyPlayerStatus = (lpsConnected, lpsSearching, lpsReady);

  TLobbyPlayerInfo = record
    PlayerId: UInt32;
    Login: string;
    Status: TLobbyPlayerStatus;
  end;

  TLobbyRoomInfo = record
    RoomId: UInt32;
    Name: string;
    MapName: string;
    Port: Word;
    CurrentPlayers: Word;
    MaxPlayers: Word;
  end;

  TLobbyPlayerArray = array of TLobbyPlayerInfo;
  TLobbyRoomArray = array of TLobbyRoomInfo;

  TLobbyWorldBase = class
  private
    FPlayers: array of TLobbyPlayerInfo;
    FRooms: array of TLobbyRoomInfo;
    FAuthValidator: IAuthValidator;
  protected
    FSystems: TWorldSystemList;
    procedure AddSystem(ASystem: IWorldSystem);
    procedure RegisterSystems; virtual;
    function FindPlayerIndex(const APlayerId: UInt32): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start; virtual;
    procedure Stop; virtual;
    procedure Update(const SecondsPassed: Single); virtual;
    function Press(const Event: TInputPressRelease): Boolean; virtual;

    property Players: TLobbyPlayerArray read FPlayers;
    property Rooms: TLobbyRoomArray read FRooms;
    property AuthValidator: IAuthValidator read FAuthValidator write FAuthValidator;
  end;

implementation

{ TLobbyWorldBase }

constructor TLobbyWorldBase.Create;
begin
  inherited Create;
  FSystems := TWorldSystemList.Create;
  RegisterSystems;
end;

destructor TLobbyWorldBase.Destroy;
begin
  FSystems.Free;
  FPlayers := nil;
  FRooms := nil;
  inherited;
end;

procedure TLobbyWorldBase.Start;
begin
end;

procedure TLobbyWorldBase.Stop;
begin
end;

procedure TLobbyWorldBase.Update(const SecondsPassed: Single);
var
  i: Integer;
begin
  for i := 0 to FSystems.Count - 1 do
    FSystems[i].Update(SecondsPassed);
end;

function TLobbyWorldBase.Press(const Event: TInputPressRelease): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to FSystems.Count - 1 do
    if FSystems[i].Press(Event) then Exit(True);
end;

procedure TLobbyWorldBase.RegisterSystems;
begin
end;

procedure TLobbyWorldBase.AddSystem(ASystem: IWorldSystem);
begin
  FSystems.Add(ASystem);
end;

function TLobbyWorldBase.FindPlayerIndex(const APlayerId: UInt32): Integer;
begin
  for Result := 0 to High(FPlayers) do
    if FPlayers[Result].PlayerId = APlayerId then
      Exit;
  Result := -1;
end;

end.
