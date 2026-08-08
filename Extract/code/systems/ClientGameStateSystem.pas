unit ClientGameStateSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, WorldSystemBase, GameSettings, GameWorld, CastleKeysMouse;

type
  TClientGameStateSystem = class(TWorldSystemBase)
  private
    FFsm: TClientGameFsm;
  public
    constructor Create(AWorldObj: TGameWorld);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    function Press(const Event: TInputPressRelease): Boolean; override;
    property Fsm: TClientGameFsm read FFsm;
  end;

implementation

uses GameWorldClient, ClientGameStates;

{ TClientGameStateSystem }

constructor TClientGameStateSystem.Create(AWorldObj: TGameWorld);
var
  GW: TGameWorldClient;
begin
  inherited Create(AWorldObj);
  GW := WorldObj as TGameWorldClient;
  FFsm := TClientGameFsm.Create;
  FFsm.RegisterState(cgsWaiting, TClientWaitingState.Create(GW));
  FFsm.RegisterState(cgsMainMenu, TClientMainMenuState.Create(GW));
  FFsm.RegisterState(cgsSettings, TClientSettingsState.Create(GW));
  FFsm.RegisterState(cgsPlaying, TClientPlayingState.Create(GW));
  FFsm.ChangeState(cgsWaiting);
end;

destructor TClientGameStateSystem.Destroy;
begin
  FFsm.Free;
  inherited Destroy;
end;

procedure TClientGameStateSystem.Update(const SecondsPassed: Single);
begin
  FFsm.Update(SecondsPassed);
end;

function TClientGameStateSystem.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := False;
end;

end.
