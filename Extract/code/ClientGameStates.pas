unit ClientGameStates;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, State, StateMachine, GameSettings, GameWorldClient,
  FirstPersonCameraBehavior,
  CastleKeysMouse, CastleUIControls;

type
  TClientGameStateBase = class(specialize TState<TClientGameState>)
  protected
    FWorld: TGameWorldClient;
  public
    constructor Create(AWorld: TGameWorldClient);
    property World: TGameWorldClient read FWorld;
  end;

  { Статус по умолчанию: загрузка мира и прочее (заглушка). }
  TClientWaitingState = class(TClientGameStateBase)
  public
    procedure Update(DeltaTime: Single); override;
  end;

  TClientMainMenuState = class(TClientGameStateBase)
  public
    procedure Enter(FromState: TClientGameState); override;
    procedure Update(DeltaTime: Single); override;
  end;

  TClientSettingsState = class(TClientGameStateBase)
  public
    procedure Update(DeltaTime: Single); override;
  end;

  TClientPlayingState = class(TClientGameStateBase)
  public
    procedure Enter(FromState: TClientGameState); override;
    procedure Update(DeltaTime: Single); override;
  end;

implementation

{ TClientGameStateBase }

constructor TClientGameStateBase.Create(AWorld: TGameWorldClient);
begin
  inherited Create;
  FWorld := AWorld;
end;

{ TClientWaitingState }

procedure TClientWaitingState.Update(DeltaTime: Single);
begin
end;

{ TClientMainMenuState }

procedure TClientMainMenuState.Enter(FromState: TClientGameState);
var
  Cont: TCastleContainer;
  FC: TFirstPersonCameraBehavior;
begin
  World.InputEnabled := False;
  Cont := World.Viewport.Container;
  if Cont <> nil then
    Cont.OverrideCursor := mcDefault;
  if World.MainPlayerTransform <> nil then
  begin
    FC := World.MainPlayerTransform.FindBehavior(TFirstPersonCameraBehavior)
      as TFirstPersonCameraBehavior;
    if FC <> nil then
      FC.CursorVisible := True;
  end;
end;

procedure TClientMainMenuState.Update(DeltaTime: Single);
begin
end;

{ TClientSettingsState }

procedure TClientSettingsState.Update(DeltaTime: Single);
begin
end;

{ TClientPlayingState }

procedure TClientPlayingState.Enter(FromState: TClientGameState);
var
  Cont: TCastleContainer;
  FC: TFirstPersonCameraBehavior;
begin
  World.InputEnabled := True;
  if World.MainPlayerTransform <> nil then
  begin
    FC := World.MainPlayerTransform.FindBehavior(TFirstPersonCameraBehavior)
      as TFirstPersonCameraBehavior;
    if FC <> nil then
      FC.CursorVisible := False;
  end;
  Cont := World.Viewport.Container;
  if Cont <> nil then
  begin
    Cont.MouseLookIgnoreNextMotion;
    Cont.OverrideCursor := mcNone;
  end;
end;

procedure TClientPlayingState.Update(DeltaTime: Single);
begin
end;

end.
