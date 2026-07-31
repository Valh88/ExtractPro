unit ClientGameStates;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, State, StateMachine, GameSettings, GameWorldClient;

type
  TClientGameStateBase = class(specialize TState<TGameState>)
  protected
    FWorld: TGameWorldClient;
  public
    constructor Create(AWorld: TGameWorldClient);
    property World: TGameWorldClient read FWorld;
  end;

  TClientLoadingState = class(TClientGameStateBase)
  public
    procedure Update(DeltaTime: Single); override;
  end;

  TClientWaitingPlayersState = class(TClientGameStateBase)
  public
    procedure Update(DeltaTime: Single); override;
  end;

  TClientPlayingState = class(TClientGameStateBase)
  public
    procedure Update(DeltaTime: Single); override;
  end;

  TClientFinishedState = class(TClientGameStateBase)
  public
    procedure Update(DeltaTime: Single); override;
  end;

implementation

{ TClientGameStateBase }

constructor TClientGameStateBase.Create(AWorld: TGameWorldClient);
begin
  inherited Create;
  FWorld := AWorld;
end;

{ TClientLoadingState }

procedure TClientLoadingState.Update(DeltaTime: Single);
begin
  ChangeState(gsWaitingPlayers);
end;

{ TClientWaitingPlayersState }

procedure TClientWaitingPlayersState.Update(DeltaTime: Single);
begin
  ChangeState(gsPlaying);
end;

{ TClientPlayingState }

procedure TClientPlayingState.Update(DeltaTime: Single);
begin
end;

{ TClientFinishedState }

procedure TClientFinishedState.Update(DeltaTime: Single);
begin
end;

end.
