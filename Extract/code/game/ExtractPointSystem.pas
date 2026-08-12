unit ExtractPointSystem;

{$mode objfpc}{$H+}

interface

uses
  CastleLog,
  GameWorld, WorldSystemBase, ClientEventBus;

type
  { Клиентская система зоны эвакуации (ExtractPoint).
    Подписывается на события зоны из ClientEventBus (cgeExtractZoneEntered/Exited),
    которые публикует TClientNetSystem при приходе msgExtractZone.
    Здесь будет вся клиентская игровая логика эвакуации (UI и т.п.). }
  TExtractPointSystem = class(TWorldSystemBase)
  private
    FSubscribed: Boolean;
    procedure OnExtractZoneEvent(const Event: TClientGameEvent);
    procedure Subscribe;
    procedure Unsubscribe;
  public
    constructor Create(AWorldObj: TGameWorld);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
  end;

implementation

{ TExtractPointSystem }

constructor TExtractPointSystem.Create(AWorldObj: TGameWorld);
begin
  inherited Create(AWorldObj);
  Subscribe;
end;

destructor TExtractPointSystem.Destroy;
begin
  Unsubscribe;
  inherited;
end;

procedure TExtractPointSystem.Subscribe;
begin
  if FSubscribed then Exit;
  GlobalClientEventBus.Subscribe(cgeExtractZoneEntered, @OnExtractZoneEvent);
  GlobalClientEventBus.Subscribe(cgeExtractZoneExited, @OnExtractZoneEvent);
  FSubscribed := True;
end;

procedure TExtractPointSystem.Unsubscribe;
begin
  if not FSubscribed then Exit;
  GlobalClientEventBus.Unsubscribe(@OnExtractZoneEvent);
  FSubscribed := False;
end;

procedure TExtractPointSystem.OnExtractZoneEvent(const Event: TClientGameEvent);
var
  P: TExtractZonePayload;
begin
  P := TExtractZonePayload(Event.Data);
  if P = nil then Exit;
  if Event.EventType = cgeExtractZoneEntered then
    WritelnLog('Client', 'ExtractPointSystem: player %d entered zone %d at (%.1f, %.1f, %.1f)',
      [P.EntityId, P.ZoneIndex, P.PosX, P.PosY, P.PosZ])
  else
    WritelnLog('Client', 'ExtractPointSystem: player %d left zone %d at (%.1f, %.1f, %.1f)',
      [P.EntityId, P.ZoneIndex, P.PosX, P.PosY, P.PosZ]);
end;

procedure TExtractPointSystem.Update(const SecondsPassed: Single);
begin
end;

end.
