unit LobbyManagerSystem;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  CastleKeysMouse, Interfaces, LobbyManager, MatchmakingSM, GameConfig,
  NetMessages, GameWorldServer;

type
  TSendToPlayerEvent = function(APlayerId: UInt32; const Msg: TNetMessage): Boolean of object;

type
  TLobbyManagerSystem = class(TInterfacedObject, IWorldSystem, IMatchmakingHost)
  private
    FManager: TLobbyManager;
    FFsm: TMatchStateMachine;
    FQueues: array[1..3] of TQueuedPlayerArray;
    FReadyPartySize: Byte;
    FPendingMatch: TQueuedPlayerArray;
    FRequireAuth: Boolean;
    FOnSendToPlayer: TSendToPlayerEvent;
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
    procedure StartReadyCheck(const Players: TQueuedPlayerArray);
    procedure NotifyReadyCheck(const Players: TQueuedPlayerArray);
    procedure NotifyReadyCheckUpdate(const Players: TQueuedPlayerArray);
    procedure NotifyReadyCheckEnd(AResult: Byte);
    procedure SetPlayerReady(const APlayerId: UInt32);
    procedure CancelPlayerMatch(const APlayerId: UInt32);
    procedure CancelCurrentMatch(ACancellingPlayerId: UInt32);
    function IsEveryoneReady: Boolean;
    function GetMatchPlayers: TQueuedPlayerArray;
    function GetReadyCheckTimeout: Single;
    procedure HandleReadyCheckTimeout;
    procedure RollbackMatch;

    property Manager: TLobbyManager read FManager;
    property Fsm: TMatchStateMachine read FFsm;
    property OnSendToPlayer: TSendToPlayerEvent read FOnSendToPlayer write FOnSendToPlayer;
    property RequireAuth: Boolean read FRequireAuth write FRequireAuth;
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
  FFsm.RegisterState(msReadyCheck, TReadyCheckState.Create(Self as IMatchmakingHost));
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
  QP.Ready := False;
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
var
  FreePort: Word;
  LobbyId: UInt32;
  Lobby: TGameWorldServer;
  M: TNetMessage;
  p: TQueuedPlayer;
begin
  FreePort := FManager.GetAvailablePort;
  LobbyId := FManager.AddLobby(FreePort, 32, FRequireAuth);
  Lobby := FManager.FindLobbyById(LobbyId);
  if Lobby <> nil then
    Lobby.NetSystem.StartServer;

  GamePort := FreePort;

  M.Init(msgStartGame, [Lo(FreePort), Hi(FreePort),
    Byte(LobbyId), Byte(LobbyId shr 8),
    Byte(LobbyId shr 16), Byte(LobbyId shr 24)]);
  for p in Players do
    if Assigned(FOnSendToPlayer) then
      FOnSendToPlayer(p.PlayerId, M);
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

procedure TLobbyManagerSystem.StartReadyCheck(const Players: TQueuedPlayerArray);
var
  i: Integer;
begin
  SetLength(FPendingMatch, Length(Players));
  for i := 0 to High(Players) do
  begin
    FPendingMatch[i] := Players[i];
    FPendingMatch[i].Ready := False;
  end;
end;

procedure TLobbyManagerSystem.NotifyReadyCheck(const Players: TQueuedPlayerArray);
var
  M: TNetMessage;
  p: TQueuedPlayer;
begin
  M.Init(msgReadyCheck);
  for p in Players do
    if Assigned(FOnSendToPlayer) then
      FOnSendToPlayer(p.PlayerId, M);
end;

procedure TLobbyManagerSystem.NotifyReadyCheckUpdate(const Players: TQueuedPlayerArray);
var
  M: TNetMessage;
  Payload: TBytes;
  i, Off: Integer;
  p: TQueuedPlayer;
begin
  SetLength(Payload, 1 + Length(Players) * 5);
  Payload[0] := Byte(Length(Players));
  for i := 0 to High(Players) do
  begin
    Off := 1 + i * 5;
    Payload[Off] := Byte(Players[i].PlayerId);
    Payload[Off + 1] := Byte(Players[i].PlayerId shr 8);
    Payload[Off + 2] := Byte(Players[i].PlayerId shr 16);
    Payload[Off + 3] := Byte(Players[i].PlayerId shr 24);
    if Players[i].Ready then
      Payload[Off + 4] := 1
    else
      Payload[Off + 4] := 0;
  end;
  M.Init(msgReadyCheckUpdate, Payload);
  for p in Players do
    if Assigned(FOnSendToPlayer) then
      FOnSendToPlayer(p.PlayerId, M);
end;

procedure TLobbyManagerSystem.NotifyReadyCheckEnd(AResult: Byte);
var
  M: TNetMessage;
  p: TQueuedPlayer;
begin
  M.Init(msgReadyCheckEnd, [AResult]);
  for p in FPendingMatch do
    if Assigned(FOnSendToPlayer) then
      FOnSendToPlayer(p.PlayerId, M);
end;

procedure TLobbyManagerSystem.SetPlayerReady(const APlayerId: UInt32);
var
  i: Integer;
begin
  for i := 0 to High(FPendingMatch) do
    if FPendingMatch[i].PlayerId = APlayerId then
    begin
      FPendingMatch[i].Ready := True;
      Exit;
    end;
end;

procedure TLobbyManagerSystem.CancelPlayerMatch(const APlayerId: UInt32);
var
  i, Len: Integer;
begin
  Len := Length(FPendingMatch);
  for i := 0 to Len - 1 do
    if FPendingMatch[i].PlayerId = APlayerId then
    begin
      FPendingMatch[i] := FPendingMatch[Len - 1];
      SetLength(FPendingMatch, Len - 1);
      Exit;
    end;
end;

procedure TLobbyManagerSystem.CancelCurrentMatch(ACancellingPlayerId: UInt32);
var
  p: TQueuedPlayer;
  M: TNetMessage;
begin
  if Length(FPendingMatch) = 0 then Exit;

  // Notify cancelling player: result=0 (out of queue)
  M.Init(msgReadyCheckEnd, [0]);
  for p in FPendingMatch do
    if p.PlayerId = ACancellingPlayerId then
    begin
      if Assigned(FOnSendToPlayer) then
        FOnSendToPlayer(p.PlayerId, M);
      Break;
    end;

  // Re-enqueue and notify remaining players: result=2 (re-enqueued)
  M.Init(msgReadyCheckEnd, [2]);
  for p in FPendingMatch do
    if p.PlayerId <> ACancellingPlayerId then
    begin
      EnqueuePlayer(p.PlayerId, string(p.Login), p.PartySize);
      if Assigned(FOnSendToPlayer) then
        FOnSendToPlayer(p.PlayerId, M);
    end;

  SetLength(FPendingMatch, 0);
  FFsm.ChangeState(msWaiting);
end;

function TLobbyManagerSystem.IsEveryoneReady: Boolean;
var
  i: Integer;
begin
  for i := 0 to High(FPendingMatch) do
    if not FPendingMatch[i].Ready then
      Exit(False);
  Result := Length(FPendingMatch) > 0;
end;

function TLobbyManagerSystem.GetMatchPlayers: TQueuedPlayerArray;
begin
  Result := FPendingMatch;
end;

function TLobbyManagerSystem.GetReadyCheckTimeout: Single;
begin
  Result := GlobalConfig.ReadyCheckTimeout;
end;

procedure TLobbyManagerSystem.HandleReadyCheckTimeout;
var
  p: TQueuedPlayer;
  M: TNetMessage;
begin
  for p in FPendingMatch do
  begin
    if p.Ready then
    begin
      EnqueuePlayer(p.PlayerId, string(p.Login), p.PartySize);
      M.Init(msgReadyCheckEnd, [2]);
    end
    else
      M.Init(msgReadyCheckEnd, [0]);
    if Assigned(FOnSendToPlayer) then
      FOnSendToPlayer(p.PlayerId, M);
  end;
  SetLength(FPendingMatch, 0);
end;

procedure TLobbyManagerSystem.RollbackMatch;
var
  p: TQueuedPlayer;
begin
  for p in FPendingMatch do
    if p.Ready then
      EnqueuePlayer(p.PlayerId, string(p.Login), p.PartySize);
  SetLength(FPendingMatch, 0);
end;

end.
