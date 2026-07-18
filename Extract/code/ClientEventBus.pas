unit ClientEventBus;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Contnrs;

type
  TClientGameEventType = (
    cgeMatchmakingStateChanged
  );

  TClientGameEvent = record
    EventType: TClientGameEventType;
    Amount: Single;
    Data: Pointer;
  end;

  TClientGameEventProc = procedure(const Event: TClientGameEvent) of object;

  TClientEventSubscriber = class
  private
    FProc: TClientGameEventProc;
    FFilter: TClientGameEventType;
  public
    constructor Create(const AFilter: TClientGameEventType; const AProc: TClientGameEventProc);
    procedure Invoke(const Event: TClientGameEvent);
    property Filter: TClientGameEventType read FFilter;
  end;

  TClientEventBus = class
  private
    FSubscribers: TObjectList;
    FQueue: array of TClientGameEvent;
    procedure ClearQueue;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Subscribe(EventType: TClientGameEventType; Callback: TClientGameEventProc);
    procedure Unsubscribe(Callback: TClientGameEventProc);
    procedure Queue(const Event: TClientGameEvent);
    procedure Flush;
  end;

function GlobalClientEventBus: TClientEventBus;

implementation

var
  _ClientEventBus: TClientEventBus = nil;

function GlobalClientEventBus: TClientEventBus;
begin
  if _ClientEventBus = nil then
    _ClientEventBus := TClientEventBus.Create;
  Result := _ClientEventBus;
end;

{ TClientEventSubscriber }

constructor TClientEventSubscriber.Create(const AFilter: TClientGameEventType; const AProc: TClientGameEventProc);
begin
  inherited Create;
  FFilter := AFilter;
  FProc := AProc;
end;

procedure TClientEventSubscriber.Invoke(const Event: TClientGameEvent);
begin
  if Event.EventType = FFilter then
    FProc(Event);
end;

{ TClientEventBus }

constructor TClientEventBus.Create;
begin
  inherited;
  FSubscribers := TObjectList.Create(True);
end;

destructor TClientEventBus.Destroy;
begin
  ClearQueue;
  FSubscribers.Free;
  inherited;
end;

procedure TClientEventBus.Subscribe(EventType: TClientGameEventType; Callback: TClientGameEventProc);
begin
  FSubscribers.Add(TClientEventSubscriber.Create(EventType, Callback));
end;

procedure TClientEventBus.Unsubscribe(Callback: TClientGameEventProc);
var
  i: Integer;
begin
  for i := FSubscribers.Count - 1 downto 0 do
    if TClientEventSubscriber(FSubscribers[i]).FProc = Callback then
      FSubscribers.Delete(i);
end;

procedure TClientEventBus.Queue(const Event: TClientGameEvent);
begin
  SetLength(FQueue, Length(FQueue) + 1);
  FQueue[High(FQueue)] := Event;
end;

procedure TClientEventBus.Flush;
var
  i, j: Integer;
begin
  for i := 0 to High(FQueue) do
    for j := 0 to FSubscribers.Count - 1 do
      TClientEventSubscriber(FSubscribers[j]).Invoke(FQueue[i]);
  ClearQueue;
end;

procedure TClientEventBus.ClearQueue;
begin
  FQueue := nil;
end;

end.