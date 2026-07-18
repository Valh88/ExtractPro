unit EventBus;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Contnrs, help_types, EntityTypes;

type
  TGameEventType = (
    gePlayerDamaged,
    gePlayerDied,
    gePlayerExtracted,
    geEnemySpawned,
    geEnemyDied,
    geRaidPhaseChanged,
    geRaidTimeWarning,
    geExtractionStarted,
    geItemPickedUp,
    geMatchmakingStateChanged
  );

  TGameEvent = record
    EventType: TGameEventType;
    EntityId: TEntityId;
    SourceId: TEntityId;
    Amount: Single;
    Position: TVector2;
    Data: Pointer;
  end;

  TGameEventProc = procedure(const Event: TGameEvent) of object;

  TEventSubscriber = class
  private
    FProc: TGameEventProc;
    FFilter: TGameEventType;
  public
    constructor Create(const AFilter: TGameEventType; const AProc: TGameEventProc);
    procedure Invoke(const Event: TGameEvent);
    property Filter: TGameEventType read FFilter;
  end;

  TEventBus = class
  private
    FSubscribers: TObjectList;
    FQueue: array of TGameEvent;
    procedure ClearQueue;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Subscribe(EventType: TGameEventType; Callback: TGameEventProc);
    procedure Unsubscribe(Callback: TGameEventProc);
    procedure Queue(const Event: TGameEvent);
    procedure Flush;
  end;

function GlobalEventBus: TEventBus;

implementation

var
  _EventBus: TEventBus = nil;

function GlobalEventBus: TEventBus;
begin
  if _EventBus = nil then
    _EventBus := TEventBus.Create;
  Result := _EventBus;
end;

{ TEventSubscriber }

constructor TEventSubscriber.Create(const AFilter: TGameEventType; const AProc: TGameEventProc);
begin
  inherited Create;
  FFilter := AFilter;
  FProc := AProc;
end;

procedure TEventSubscriber.Invoke(const Event: TGameEvent);
begin
  if Event.EventType = FFilter then
    FProc(Event);
end;

{ TEventBus }

constructor TEventBus.Create;
begin
  inherited;
  FSubscribers := TObjectList.Create(True);
end;

destructor TEventBus.Destroy;
begin
  ClearQueue;
  FSubscribers.Free;
  inherited;
end;

procedure TEventBus.Subscribe(EventType: TGameEventType; Callback: TGameEventProc);
begin
  FSubscribers.Add(TEventSubscriber.Create(EventType, Callback));
end;

procedure TEventBus.Unsubscribe(Callback: TGameEventProc);
var
  i: Integer;
begin
  for i := FSubscribers.Count - 1 downto 0 do
    if TEventSubscriber(FSubscribers[i]).FProc = Callback then
      FSubscribers.Delete(i);
end;

procedure TEventBus.Queue(const Event: TGameEvent);
begin
  SetLength(FQueue, Length(FQueue) + 1);
  FQueue[High(FQueue)] := Event;
end;

procedure TEventBus.Flush;
var
  i, j: Integer;
begin
  for i := 0 to High(FQueue) do
    for j := 0 to FSubscribers.Count - 1 do
      TEventSubscriber(FSubscribers[j]).Invoke(FQueue[i]);
  ClearQueue;
end;

procedure TEventBus.ClearQueue;
begin
  FQueue := nil;
end;

end.