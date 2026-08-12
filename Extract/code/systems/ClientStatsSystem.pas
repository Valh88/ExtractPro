unit ClientStatsSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, WorldSystemBase, GameWorld, ClientEventBus;

type
  { Клиентская система статистики: периодически публикует cgePingUpdate
    (пинг до сервера в мс). FPS обновляется напрямую в TViewMain (источник там). }
  TClientStatsSystem = class(TWorldSystemBase)
  private
    FTimer: Single;
    FInterval: Single;
  public
    constructor Create(AWorldObj: TGameWorld);
    procedure Update(const SecondsPassed: Single); override;
  end;

implementation

uses GameWorldClient, ClientNetSystem;

{ TClientStatsSystem }

constructor TClientStatsSystem.Create(AWorldObj: TGameWorld);
begin
  inherited Create(AWorldObj);
  FInterval := 0.5;
  FTimer := 0;
end;

procedure TClientStatsSystem.Update(const SecondsPassed: Single);
var
  GW: TGameWorldClient;
  E: TClientGameEvent;
begin
  FTimer := FTimer + SecondsPassed;
  if FTimer < FInterval then
    Exit;
  FTimer := 0;

  GW := WorldObj as TGameWorldClient;
  E.EventType := cgePingUpdate;
  E.Amount := 0;
  E.Data := nil;
  if (GW.NetSystem <> nil) and (GW.NetSystem.Client <> nil) then
    E.Amount := GW.NetSystem.Client.GetRoundTripTimeMS;
  GlobalClientEventBus.Queue(E);
  GlobalClientEventBus.Flush;
end;

end.
