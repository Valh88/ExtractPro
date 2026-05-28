unit StateMachine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fgl, State;

type
  generic TStateChangeCallback<T> = procedure(NewState, OldState: T) of object;
  generic TStateMachine<T> = class(specialize TStateMachineBase<T>)
  public
  type
    TConcreteState = specialize TState<T>;
    TStateMap = specialize TFPGMap<integer, TConcreteState>;
    TStateChangeEvent = specialize TStateChangeCallback<T>;
    TCallbackList = specialize TFPGList<TStateChangeEvent>;
  private
    FStates: TStateMap;
    FCurrentState: T;
    FPreviousState: T;
    FIsLocked: boolean;
    FInitialized: boolean;
    FHasCurrentState: boolean;
    FOnStateChange: TCallbackList;
    FOwnsStates: boolean;

    function GetCurrentStateObj: TConcreteState;
    function StateToInt(AState: T): integer;
  public
    constructor Create(AOwnsStates: boolean = True);
    destructor Destroy; override;
    procedure RegisterState(StateId: T; StateObj: TConcreteState);
    function GetState(StateId: T): TConcreteState;
    function HasState(StateId: T): boolean;
    procedure ChangeState(NewState: T); override;
    procedure Update(DeltaTime: single);
    procedure AddStateChangeListener(Callback: TStateChangeEvent);
    procedure RemoveStateChangeListener(Callback: TStateChangeEvent);
    procedure GoToPreviousState;
    property CurrentState: T read FCurrentState;
    property PreviousState: T read FPreviousState;
    property CurrentStateObj: TConcreteState read GetCurrentStateObj;
    property IsLocked: boolean read FIsLocked write FIsLocked;
    property HasCurrentState: boolean read FHasCurrentState;
    property OwnsStates: boolean read FOwnsStates write FOwnsStates;
  end;

implementation

{ TStateMachine }

constructor TStateMachine.Create(AOwnsStates: boolean);
begin
  inherited Create;
  FStates := TStateMap.Create;
  FOnStateChange := TCallbackList.Create;
  FIsLocked := False;
  FInitialized := True;
  FHasCurrentState := False;
  FOwnsStates := AOwnsStates;
end;

destructor TStateMachine.Destroy;
var
  I: integer;
begin
  if FOwnsStates then
  begin
    for I := 0 to FStates.Count - 1 do
      FStates.Data[I].Free;
  end;
  FStates.Free;
  FOnStateChange.Free;
  inherited Destroy;
end;

function TStateMachine.StateToInt(AState: T): integer;
begin
  Result := integer(AState);
end;

procedure TStateMachine.RegisterState(StateId: T; StateObj: TConcreteState);
var
  Key: integer;
begin
  Key := StateToInt(StateId);
  FStates.Add(Key, StateObj);
  StateObj.StateMachine := Self;
end;

function TStateMachine.GetState(StateId: T): TConcreteState;
var
  Key, Index: integer;
begin
  Key := StateToInt(StateId);
  Index := FStates.IndexOf(Key);
  if Index >= 0 then
    Result := FStates.Data[Index]
  else
    Result := nil;
end;

function TStateMachine.HasState(StateId: T): boolean;
begin
  Result := FStates.IndexOf(StateToInt(StateId)) >= 0;
end;

function TStateMachine.GetCurrentStateObj: TConcreteState;
begin
  if FHasCurrentState then
    Result := GetState(FCurrentState)
  else
    Result := nil;
end;

procedure TStateMachine.ChangeState(NewState: T);
var
  OldState: T;
  OldStateObj, NewStateObj: TConcreteState;
  I: integer;
begin
  if FIsLocked then
    Exit;

  if FHasCurrentState and (StateToInt(NewState) = StateToInt(FCurrentState)) then
    Exit;

  OldState := FCurrentState;

  if FHasCurrentState then
  begin
    OldStateObj := GetState(OldState);
    if OldStateObj <> nil then
      OldStateObj.Exit(NewState);
  end;

  FPreviousState := OldState;
  FCurrentState := NewState;
  FHasCurrentState := True;

  NewStateObj := GetState(NewState);
  if NewStateObj <> nil then
    NewStateObj.Enter(OldState);

  for I := 0 to FOnStateChange.Count - 1 do
    FOnStateChange[I](NewState, OldState);
end;

procedure TStateMachine.Update(DeltaTime: single);
var
  StateObj: TConcreteState;
begin
  if FHasCurrentState then
  begin
    StateObj := GetState(FCurrentState);
    if StateObj <> nil then
      StateObj.Update(DeltaTime);
  end;
end;

procedure TStateMachine.AddStateChangeListener(Callback: TStateChangeEvent);
begin
  FOnStateChange.Add(Callback);
end;

procedure TStateMachine.RemoveStateChangeListener(Callback: TStateChangeEvent);
var
  Index: integer;
begin
  Index := FOnStateChange.IndexOf(Callback);
  if Index >= 0 then
    FOnStateChange.Delete(Index);
end;

procedure TStateMachine.GoToPreviousState;
begin
  if FHasCurrentState then
    ChangeState(FPreviousState);
end;

end.
