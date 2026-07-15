unit LobbyWorld;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, GameConfig, Interfaces,
  AuthTypes, CastleKeysMouse;

type
  TLobbyPlayerInfo = record
    PlayerId: UInt32;
    Login: string;
    Data: TObject;
  end;

  TLobbyPlayerArray = array of TLobbyPlayerInfo;

  TLobbyWorldBase = class
  private
    FPlayers: array of TLobbyPlayerInfo;
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
    function AddPlayer(const APlayerId: UInt32; const ALogin: string): Boolean;
    procedure RemovePlayer(const APlayerId: UInt32);

    property Players: TLobbyPlayerArray read FPlayers;
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
var
  i: Integer;
begin
  FSystems.Free;
  for i := 0 to High(FPlayers) do
    FPlayers[i].Data.Free;
  FPlayers := nil;
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

function TLobbyWorldBase.AddPlayer(const APlayerId: UInt32; const ALogin: string): Boolean;
var
  L: Integer;
begin
  if FindPlayerIndex(APlayerId) <> -1 then Exit(False);
  L := Length(FPlayers);
  SetLength(FPlayers, L + 1);
  FPlayers[L].PlayerId := APlayerId;
  FPlayers[L].Login := ALogin;
  FPlayers[L].Data := nil;
  Result := True;
end;

procedure TLobbyWorldBase.RemovePlayer(const APlayerId: UInt32);
var
  Idx, L: Integer;
begin
  Idx := FindPlayerIndex(APlayerId);
  if Idx = -1 then Exit;
  L := High(FPlayers);
  FPlayers[Idx].Data.Free;
  FPlayers[Idx] := FPlayers[L];
  SetLength(FPlayers, L);
end;

end.
