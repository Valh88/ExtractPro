unit GameStates;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, State, StateMachine, GameWorldServer, GameSettings;

type
  TGameStateBase = class(specialize TState<TGameState>)
  protected
    FWorld: TGameWorldServer;
  public
    constructor Create(AWorld: TGameWorldServer);
    property World: TGameWorldServer read FWorld;
  end;

  TLoadingState = class(TGameStateBase)
  public
    procedure Update(DeltaTime: Single); override;
  end;

  TWaitingPlayersState = class(TGameStateBase)
  public
    procedure Update(DeltaTime: Single); override;
  end;

  TPlayingState = class(TGameStateBase)
  public
    procedure Update(DeltaTime: Single); override;
  end;

  TFinishedState = class(TGameStateBase)
  public
    procedure Update(DeltaTime: Single); override;
  end;

implementation

{ TGameStateBase }

constructor TGameStateBase.Create(AWorld: TGameWorldServer);
begin
  inherited Create;
  FWorld := AWorld;
end;

{ TLoadingState }

procedure TLoadingState.Update(DeltaTime: Single);
begin
  FWorld.EnsureMapLoaded;
  FWorld.LoadMapData;
  ChangeState(gsWaitingPlayers);
end;

{ TWaitingPlayersState }

procedure TWaitingPlayersState.Update(DeltaTime: Single);
begin
  ChangeState(gsPlaying);
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
