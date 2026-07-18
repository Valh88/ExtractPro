unit LobbyManagerSystem;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  CastleKeysMouse, Interfaces, LobbyManager, MatchmakingSM;

type
  TLobbyManagerSystem = class(TInterfacedObject, IWorldSystem, IMatchmakingHost)
  private
    FManager: TLobbyManager;
    FFsm: TMatchStateMachine;
    FQueue: TQueuedPlayerArray;
    FPartiesPerMatch: Integer;
  public
    constructor Create(AManager: TLobbyManager;
      APartiesPerMatch: Integer = DefaultPartiesPerMatch);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single);
    function Press(const Event: TInputPressRelease): Boolean;

    procedure EnqueuePlayer(const APlayerId: UInt32; const ALogin: string; APartySize: Byte);
    function DequeuePlayer(const APlayerId: UInt32): Boolean;

    function TakePlayers(ACount: Integer): TQueuedPlayerArray;
    procedure DistributeGame(const Players: array of TQueuedPlayer; out GamePort: Word);
    function GetQueue: TQueuedPlayerArray;
    function GetPartiesPerMatch: Integer;

    property Manager: TLobbyManager read FManager;
    property Fsm: TMatchStateMachine read FFsm;
  end;

implementation

{ TLobbyManagerSystem }

constructor TLobbyManagerSystem.Create(AManager: TLobbyManager;
  APartiesPerMatch: Integer = DefaultPartiesPerMatch);
begin
  inherited Create;
  FManager := AManager;
  FPartiesPerMatch := APartiesPerMatch;
  FFsm := TMatchStateMachine.Create;
  FFsm.RegisterState(msWaiting, TWaitingState.Create(Self as IMatchmakingHost));
  FFsm.RegisterState(msGenerating, TGeneratingState.Create(Self as IMatchmakingHost));
end;

destructor TLobbyManagerSystem.Destroy;
begin
  FFsm.Free;
  inherited;
end;

procedure TLobbyManagerSystem.Update(const SecondsPassed: Single);
begin
  FFsm.Update(SecondsPassed);
end;

function TLobbyManagerSystem.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := False;
end;

procedure TLobbyManagerSystem.EnqueuePlayer(const APlayerId: UInt32;
  const ALogin: string; APartySize: Byte);
var
  QP: TQueuedPlayer;
begin
  QP.PlayerId := APlayerId;
  QP.Login := ShortString(ALogin);
  QP.PartySize := APartySize;
  SetLength(FQueue, Length(FQueue) + 1);
  FQueue[High(FQueue)] := QP;
end;

function TLobbyManagerSystem.DequeuePlayer(const APlayerId: UInt32): Boolean;
var
  i, Len: Integer;
begin
  Len := Length(FQueue);
  for i := 0 to Len - 1 do
    if FQueue[i].PlayerId = APlayerId then
    begin
      FQueue[i] := FQueue[Len - 1];
      SetLength(FQueue, Len - 1);
      Exit(True);
    end;
  Result := False;
end;

function TLobbyManagerSystem.TakePlayers(ACount: Integer): TQueuedPlayerArray;
var
  TakeLen, RemainLen, i: Integer;
begin
  if ACount <= 0 then
    Exit(nil);
  TakeLen := Length(FQueue);
  if TakeLen > ACount then
    TakeLen := ACount;

  SetLength(Result, TakeLen);
  for i := 0 to TakeLen - 1 do
    Result[i] := FQueue[i];

  RemainLen := Length(FQueue) - TakeLen;
  for i := 0 to RemainLen - 1 do
    FQueue[i] := FQueue[i + TakeLen];
  SetLength(FQueue, RemainLen);
end;

procedure TLobbyManagerSystem.DistributeGame(const Players: array of TQueuedPlayer;
  out GamePort: Word);
begin
  GamePort := FManager.GetGameLobbyPort;
end;

function TLobbyManagerSystem.GetQueue: TQueuedPlayerArray;
begin
  Result := FQueue;
end;

function TLobbyManagerSystem.GetPartiesPerMatch: Integer;
begin
  Result := FPartiesPerMatch;
end;

end.
