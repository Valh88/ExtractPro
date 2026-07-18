unit MatchmakingSM;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, State, StateMachine;

const
  DefaultPartiesPerMatch = 3;

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
    function TakePlayers(ACount: Integer): TQueuedPlayerArray;
    procedure DistributeGame(const Players: array of TQueuedPlayer; out GamePort: Word);
    function DequeuePlayer(const APlayerId: UInt32): Boolean;
    function GetQueue: TQueuedPlayerArray;
    function GetPartiesPerMatch: Integer;
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
begin
  if Length(FHost.GetQueue) >= FHost.GetPartiesPerMatch then
    ChangeState(msGenerating);
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
begin
  Players := FHost.TakePlayers(FHost.GetPartiesPerMatch);
  if Length(Players) = 0 then
  begin
    ChangeState(msWaiting);
    System.Exit;
  end;

  FHost.DistributeGame(Players, GamePort);
  ChangeState(msWaiting);
end;

end.
