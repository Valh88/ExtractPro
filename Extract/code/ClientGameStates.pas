unit ClientGameStates;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, State, StateMachine, GameSettings, GameWorldClient;

type
  TClientGameStateBase = class(specialize TState<TClientGameState>)
  protected
    FWorld: TGameWorldClient;
  public
    constructor Create(AWorld: TGameWorldClient);
    property World: TGameWorldClient read FWorld;
  end;

  TClientMainMenuState = class(TClientGameStateBase)
  public
    procedure Update(DeltaTime: Single); override;
  end;

  TClientSettingsState = class(TClientGameStateBase)
  public
    procedure Update(DeltaTime: Single); override;
  end;

  TClientPlayingState = class(TClientGameStateBase)
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

{ TClientMainMenuState }

procedure TClientMainMenuState.Update(DeltaTime: Single);
begin
end;

{ TClientSettingsState }

procedure TClientSettingsState.Update(DeltaTime: Single);
begin
end;

{ TClientPlayingState }

procedure TClientPlayingState.Update(DeltaTime: Single);
begin
end;

end.
