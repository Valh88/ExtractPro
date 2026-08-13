unit ExtractPointSystem;

{$mode objfpc}{$H+}

interface

uses
  CastleLog,
  help_types, GameWorld, WorldSystemBase, ClientEventBus, GameConfig;

type
  { Клиентское отображение таймера экстракции (ромб + цифра).
    Управляется только серверными событиями входа/выхода/отмены,
    FSM не проверяет — таймер всегда виден, меню поверх по стеку. }
  TExtractPointSystem = class(TWorldSystemBase)
  private
    FSubscribed: Boolean;
    FInZone: Boolean;
    FCountdownLeft: Single;
    procedure OnExtractZoneEvent(const Event: TClientGameEvent);
    procedure Subscribe;
    procedure Unsubscribe;
    procedure ShowTimer;
    procedure HideTimer;
    procedure SetCountdownDigit(const AValue: Integer);
    function MyEntityId: TEntityId;
  public
    constructor Create(AWorldObj: TGameWorld);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
  end;

implementation

uses
  CastleControls, Math, SysUtils,
  GameWorldClient, GameViewMain;

{ TExtractPointSystem }

constructor TExtractPointSystem.Create(AWorldObj: TGameWorld);
begin
  inherited Create(AWorldObj);
  FInZone := False;
  FCountdownLeft := 0;
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
  GlobalClientEventBus.Subscribe(cgeExtractZoneCancelled, @OnExtractZoneEvent);
  FSubscribed := True;
end;

procedure TExtractPointSystem.Unsubscribe;
begin
  if not FSubscribed then Exit;
  GlobalClientEventBus.Unsubscribe(@OnExtractZoneEvent);
  FSubscribed := False;
end;

function TExtractPointSystem.MyEntityId: TEntityId;
begin
  if (WorldObj is TGameWorldClient) and
     (TGameWorldClient(WorldObj).NetSystem <> nil) then
    Result := TGameWorldClient(WorldObj).NetSystem.MyEntityId
  else
    Result := 0;
end;

procedure TExtractPointSystem.ShowTimer;
begin
  if (ViewMain = nil) or (ViewMain.ExtractTimerDesign = nil) then Exit;
  ViewMain.ExtractTimerDesign.Exists := True;
  FInZone := True;
  FCountdownLeft := GlobalConfig.ExtractionTime;
  SetCountdownDigit(Ceil(FCountdownLeft));
end;

procedure TExtractPointSystem.HideTimer;
begin
  if (ViewMain = nil) or (ViewMain.ExtractTimerDesign = nil) then Exit;
  ViewMain.ExtractTimerDesign.Exists := False;
  FInZone := False;
  FCountdownLeft := 0;
end;

procedure TExtractPointSystem.SetCountdownDigit(const AValue: Integer);
var
  Lbl: TCastleLabel;
begin
  if (ViewMain = nil) or (ViewMain.ExtractTimerDesign = nil) then Exit;
  Lbl := ViewMain.ExtractTimerDesign.DesignedComponent('TimerLabel') as TCastleLabel;
  if Lbl <> nil then
    Lbl.Caption := IntToStr(AValue);
end;

procedure TExtractPointSystem.OnExtractZoneEvent(const Event: TClientGameEvent);
var
  P: TExtractZonePayload;
begin
  P := TExtractZonePayload(Event.Data);
  if P = nil then Exit;
  if P.EntityId <> MyEntityId then Exit;
  case Event.EventType of
    cgeExtractZoneEntered:
      ShowTimer;
    cgeExtractZoneExited, cgeExtractZoneCancelled:
      HideTimer;
  end;
end;

procedure TExtractPointSystem.Update(const SecondsPassed: Single);
begin
  if not FInZone then Exit;
  FCountdownLeft := FCountdownLeft - SecondsPassed;
  if FCountdownLeft <= 0 then
  begin
    WritelnLog('Client', 'Extraction complete (stub)');
    HideTimer;
  end
  else
    SetCountdownDigit(Ceil(FCountdownLeft));
end;

end.
