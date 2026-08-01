unit GameStates;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, State, StateMachine, GameWorldServer, GameSettings;

type
  TServerGameStateBase = class(specialize TState<TServerGameState>)
  protected
    FWorld: TGameWorldServer;
    FTimer: Single;
  public
    constructor Create(AWorld: TGameWorldServer);
    property World: TGameWorldServer read FWorld;
  end;

  TStartState = class(TServerGameStateBase)
  public
    procedure Enter(FromState: TServerGameState); override;
    procedure Update(DeltaTime: Single); override;
  end;

  TLoadingState = class(TServerGameStateBase)
  public
    procedure Enter(FromState: TServerGameState); override;
    procedure Update(DeltaTime: Single); override;
  end;

  TWaitingPlayersState = class(TServerGameStateBase)
  public
    procedure Enter(FromState: TServerGameState); override;
    procedure Update(DeltaTime: Single); override;
  end;

  TPlayingState = class(TServerGameStateBase)
  public
    procedure Enter(FromState: TServerGameState); override;
  end;

  TFinishedState = class(TServerGameStateBase)
  public
    procedure Enter(FromState: TServerGameState); override;
  end;

implementation

{ TServerGameStateBase }

constructor TServerGameStateBase.Create(AWorld: TGameWorldServer);
begin
  inherited Create;
  FWorld := AWorld;
end;

{ TStartState }

procedure TStartState.Enter(FromState: TServerGameState);
begin
  FTimer := 0;
end;

procedure TStartState.Update(DeltaTime: Single);
begin
  FTimer := FTimer + DeltaTime;
  if FTimer >= 1.0 then
    ChangeState(sgsLoading);
end;

{ TLoadingState }

procedure TLoadingState.Enter(FromState: TServerGameState);
begin
  FTimer := 0;
  FWorld.EnsureMapLoaded;
  FWorld.LoadMapData;
end;

procedure TLoadingState.Update(DeltaTime: Single);
begin
  FTimer := FTimer + DeltaTime;
  if FTimer >= 1.0 then
    ChangeState(sgsWaitingPlayers);
end;

{ TWaitingPlayersState }

procedure TWaitingPlayersState.Enter(FromState: TServerGameState);
begin
  FTimer := 0;
end;

procedure TWaitingPlayersState.Update(DeltaTime: Single);
begin
  FTimer := FTimer + DeltaTime;
  if FTimer >= 1.0 then
    ChangeState(sgsPlaying);
end;

{ TPlayingState }

procedure TPlayingState.Enter(FromState: TServerGameState);
begin
end;

{ TFinishedState }

procedure TFinishedState.Enter(FromState: TServerGameState);
begin
end;

end.
