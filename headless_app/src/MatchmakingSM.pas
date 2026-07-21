unit MatchmakingSM;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, State, StateMachine;

type
  TMatchState = (msWaiting, msGenerating);

  TQueuedPlayer = record
    PlayerId: UInt32;
    Login: ShortString;
    PartySize: Byte;
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
  GamePort: Word;
  PartySize: Byte;
begin
  PartySize := FHost.GetReadyPartySize;
  Players := FHost.TakePlayers(FHost.GetPartiesPerMatch, PartySize);
  if Length(Players) = 0 then
  begin
    ChangeState(msWaiting);
    System.Exit;
  end;

  FHost.DistributeGame(Players, GamePort);
  ChangeState(msWaiting);
end;

end.
