unit MatchmakingSM;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, State, StateMachine, GameConfig;

type
  TMatchState = (msWaiting, msGenerating, msReadyCheck);

  TQueuedPlayer = record
    PlayerId: UInt32;
    Login: ShortString;
    PartySize: Byte;
    Ready: Boolean;
  end;

  TQueuedPlayerArray = array of TQueuedPlayer;

  IMatchmakingHost = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF0123456789}']
    function TakePlayers(ACount: Integer; APartySize: Byte): TQueuedPlayerArray;
    procedure DistributeGame(const Players: array of TQueuedPlayer; out GamePort: Word);
    function DequeuePlayer(const APlayerId: UInt32): Boolean;
    function GetQueueSize(APartySize: Byte): Integer;
    function GetPartiesPerMatch: Integer;
    procedure SetReadyPartySize(APartySize: Byte);
    function GetReadyPartySize: Byte;
    procedure StartReadyCheck(const Players: TQueuedPlayerArray);
    procedure NotifyReadyCheck(const Players: TQueuedPlayerArray);
    procedure SetPlayerReady(const APlayerId: UInt32);
    procedure CancelPlayerMatch(const APlayerId: UInt32);
    function IsEveryoneReady: Boolean;
    function GetMatchPlayers: TQueuedPlayerArray;
    function GetReadyCheckTimeout: Single;
    procedure RollbackMatch;
  end;

  TMatchStateBase = specialize TState<TMatchState>;
  TMatchStateMachine = specialize TStateMachine<TMatchState>;

  TWaitingState = class(TMatchStateBase)
  private
    FHost: IMatchmakingHost;
  public
    constructor Create(AHost: IMatchmakingHost); reintroduce;
    procedure Update(DeltaTime: single); override;
  end;

  TGeneratingState = class(TMatchStateBase)
  private
    FHost: IMatchmakingHost;
  public
    constructor Create(AHost: IMatchmakingHost); reintroduce;
    procedure Enter(FromState: TMatchState); override;
  end;

  TReadyCheckState = class(TMatchStateBase)
  private
    FHost: IMatchmakingHost;
    FElapsed: Single;
  public
    constructor Create(AHost: IMatchmakingHost); reintroduce;
    procedure Enter(FromState: TMatchState); override;
    procedure Update(DeltaTime: single); override;
  end;

implementation

{ TWaitingState }

constructor TWaitingState.Create(AHost: IMatchmakingHost);
begin
  inherited Create;
  FHost := AHost;
end;

procedure TWaitingState.Update(DeltaTime: single);
var
  PS: Byte;
  Needed: Integer;
begin
  for PS in [1, 3] do
  begin
    Needed := FHost.GetPartiesPerMatch * PS;
    if FHost.GetQueueSize(PS) >= Needed then
    begin
      FHost.SetReadyPartySize(PS);
      ChangeState(msGenerating);
      Break;
    end;
  end;
end;

{ TGeneratingState }

constructor TGeneratingState.Create(AHost: IMatchmakingHost);
begin
  inherited Create;
  FHost := AHost;
end;

procedure TGeneratingState.Enter(FromState: TMatchState);
var
  Players: TQueuedPlayerArray;
  PartySize: Byte;
begin
  PartySize := FHost.GetReadyPartySize;
  Players := FHost.TakePlayers(FHost.GetPartiesPerMatch, PartySize);
  if Length(Players) = 0 then
  begin
    ChangeState(msWaiting);
    System.Exit;
  end;

  FHost.StartReadyCheck(Players);
  ChangeState(msReadyCheck);
end;

{ TReadyCheckState }

constructor TReadyCheckState.Create(AHost: IMatchmakingHost);
begin
  inherited Create;
  FHost := AHost;
end;

procedure TReadyCheckState.Enter(FromState: TMatchState);
begin
  FElapsed := 0;
  FHost.NotifyReadyCheck(FHost.GetMatchPlayers);
end;

procedure TReadyCheckState.Update(DeltaTime: single);
var
  Players: TQueuedPlayerArray;
  GamePort: Word;
begin
  FElapsed := FElapsed + DeltaTime;
  if FElapsed >= FHost.GetReadyCheckTimeout then
  begin
    FHost.RollbackMatch;
    ChangeState(msWaiting);
    System.Exit;
  end;

  if FHost.IsEveryoneReady then
  begin
    Players := FHost.GetMatchPlayers;
    FHost.DistributeGame(Players, GamePort);
    ChangeState(msWaiting);
  end;
end;

end.
