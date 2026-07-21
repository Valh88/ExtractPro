unit LobbyManagerSystem;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  CastleKeysMouse, Interfaces, LobbyManager, MatchmakingSM, GameConfig;

type
  TLobbyManagerSystem = class(TInterfacedObject, IWorldSystem, IMatchmakingHost)
  private
    FManager: TLobbyManager;
    FFsm: TMatchStateMachine;
    FQueues: array[1..3] of TQueuedPlayerArray;
    FReadyPartySize: Byte;
    function GetQueueSize(APartySize: Byte): Integer;
  public
    constructor Create(AManager: TLobbyManager);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single);
    function Press(const Event: TInputPressRelease): Boolean;

    procedure EnqueuePlayer(const APlayerId: UInt32; const ALogin: string; APartySize: Byte);
    function DequeuePlayer(const APlayerId: UInt32): Boolean;

    function TakePlayers(ACount: Integer; APartySize: Byte): TQueuedPlayerArray;
    procedure DistributeGame(const Players: array of TQueuedPlayer; out GamePort: Word);
    function GetPartiesPerMatch: Integer;
    procedure SetReadyPartySize(APartySize: Byte);
    function GetReadyPartySize: Byte;

    property Manager: TLobbyManager read FManager;
    property Fsm: TMatchStateMachine read FFsm;
  end;

implementation

{ TLobbyManagerSystem }

constructor TLobbyManagerSystem.Create(AManager: TLobbyManager);
begin
  inherited Create;
  FManager := AManager;
  FFsm := TMatchStateMachine.Create;
  FFsm.RegisterState(msWaiting, TWaitingState.Create(Self as IMatchmakingHost));
  FFsm.RegisterState(msGenerating, TGeneratingState.Create(Self as IMatchmakingHost));
  FFsm.ChangeState(msWaiting);
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
  if (APartySize < Low(FQueues)) or (APartySize > High(FQueues)) then
    APartySize := 1;
  QP.PlayerId := APlayerId;
  QP.Login := ShortString(ALogin);
  QP.PartySize := APartySize;
  SetLength(FQueues[APartySize], Length(FQueues[APartySize]) + 1);
  FQueues[APartySize][High(FQueues[APartySize])] := QP;
end;

function TLobbyManagerSystem.DequeuePlayer(const APlayerId: UInt32): Boolean;
var
  i, Len: Integer;
  PS: Byte;
begin
  for PS := Low(FQueues) to High(FQueues) do
  begin
    Len := Length(FQueues[PS]);
    for i := 0 to Len - 1 do
      if FQueues[PS][i].PlayerId = APlayerId then
      begin
        FQueues[PS][i] := FQueues[PS][Len - 1];
        SetLength(FQueues[PS], Len - 1);
        Exit(True);
      end;
  end;
  Result := False;
end;

function TLobbyManagerSystem.TakePlayers(ACount: Integer; APartySize: Byte): TQueuedPlayerArray;
var
  i, TakeLen, RemainLen: Integer;
begin
  TakeLen := ACount * APartySize;
  if (ACount <= 0) or (Length(FQueues[APartySize]) < TakeLen) then
    Exit(nil);

  SetLength(Result, TakeLen);
  for i := 0 to TakeLen - 1 do
    Result[i] := FQueues[APartySize][i];

  RemainLen := Length(FQueues[APartySize]) - TakeLen;
  for i := 0 to RemainLen - 1 do
    FQueues[APartySize][i] := FQueues[APartySize][i + TakeLen];
  SetLength(FQueues[APartySize], RemainLen);
end;

procedure TLobbyManagerSystem.DistributeGame(const Players: array of TQueuedPlayer;
  out GamePort: Word);
begin
  GamePort := FManager.GetGameLobbyPort;
  GamePort := FManager.GetGameLobbyPort;
end;

function TLobbyManagerSystem.GetQueueSize(APartySize: Byte): Integer;
begin
  if (APartySize >= Low(FQueues)) and (APartySize <= High(FQueues)) then
    Result := Length(FQueues[APartySize])
  else
    Result := 0;
end;

function TLobbyManagerSystem.GetPartiesPerMatch: Integer;
begin
  Result := GlobalConfig.PartiesPerMatch;
end;

procedure TLobbyManagerSystem.SetReadyPartySize(APartySize: Byte);
begin
  FReadyPartySize := APartySize;
end;

function TLobbyManagerSystem.GetReadyPartySize: Byte;
begin
  Result := FReadyPartySize;
end;

end.
