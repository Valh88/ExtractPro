unit GameStates;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, State, StateMachine, GameWorldServer, GameSettings;

type
  TServerGameStateBase = class(specialize TState<TServerGameState>)
  protected
    FWorld: TGameWorldServer;
  public
    constructor Create(AWorld: TGameWorldServer);
    property World: TGameWorldServer read FWorld;
  end;

  TLoadingState = class(TServerGameStateBase)
  public
    procedure Update(DeltaTime: Single); override;
  end;

  TWaitingPlayersState = class(TServerGameStateBase)
  public
    procedure Update(DeltaTime: Single); override;
  end;

  TPlayingState = class(TServerGameStateBase)
  public
    procedure Update(DeltaTime: Single); override;
  end;

  TFinishedState = class(TServerGameStateBase)
  public
    procedure Update(DeltaTime: Single); override;
  end;

implementation

{ TServerGameStateBase }

constructor TServerGameStateBase.Create(AWorld: TGameWorldServer);
begin
  inherited Create;
  FWorld := AWorld;
end;

{ TLoadingState }

procedure TLoadingState.Update(DeltaTime: Single);
begin
  FWorld.EnsureMapLoaded;
  FWorld.LoadMapData;
  ChangeState(sgsWaitingPlayers);
end;

{ TWaitingPlayersState }

procedure TWaitingPlayersState.Update(DeltaTime: Single);
begin
  ChangeState(sgsPlaying);
end;

{ TPlayingState }

procedure TPlayingState.Update(DeltaTime: Single);
begin
end;

{ TFinishedState }

procedure TFinishedState.Update(DeltaTime: Single);
begin
end;

end.
