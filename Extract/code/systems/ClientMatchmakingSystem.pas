unit ClientMatchmakingSystem;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes,
  LobbySystemBase, LobbyWorld, NetMessages, RpcClient,
  ClientEventBus;

type
  TMatchmakingState = (msIdle, msPending, msSearching, msConfirming);

  TClientMatchmakingSystem = class(TLobbySystemBase)
  private
    FRpc: TRpcClient;
    FState: TMatchmakingState;
    FPendingPartySize: Byte;
    procedure PublishState;
    procedure OnPartySizeChanged(const Event: TClientGameEvent);
    procedure OnReadyCheck(const Event: TClientGameEvent);
  public
    constructor Create(ALobbyWorld: TLobbyWorldBase; ARpc: TRpcClient);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    procedure Enqueue;
    procedure Dequeue;
    procedure StartConfirm;
    procedure EndConfirm;
    procedure SendReadyCheck;
    procedure SendReadyCancel;
    property State: TMatchmakingState read FState;
    property PartySize: Byte read FPendingPartySize;
  end;

implementation

constructor TClientMatchmakingSystem.Create(ALobbyWorld: TLobbyWorldBase;
  ARpc: TRpcClient);
begin
  inherited Create(ALobbyWorld);
  FRpc := ARpc;
  FState := msIdle;
  FPendingPartySize := 1;
  GlobalClientEventBus.Subscribe(cgePartySizeChanged, @OnPartySizeChanged);
  GlobalClientEventBus.Subscribe(cgeReadyCheck, @OnReadyCheck);
end;

destructor TClientMatchmakingSystem.Destroy;
begin
  GlobalClientEventBus.Unsubscribe(@OnPartySizeChanged);
  GlobalClientEventBus.Unsubscribe(@OnReadyCheck);
  inherited;
end;

procedure TClientMatchmakingSystem.PublishState;
var
  E: TClientGameEvent;
begin
  E.EventType := cgeMatchmakingStateChanged;
  case FState of
    msIdle:      E.Amount := 0.0;
    msPending:   E.Amount := 0.5;
    msSearching: E.Amount := 1.0;
    msConfirming: E.Amount := 2.0;
  end;
  GlobalClientEventBus.Queue(E);
  GlobalClientEventBus.Flush;
end;

procedure TClientMatchmakingSystem.Update(const SecondsPassed: Single);
begin
end;

procedure TClientMatchmakingSystem.OnPartySizeChanged(const Event: TClientGameEvent);
begin
  FPendingPartySize := Round(Event.Amount);
end;

procedure TClientMatchmakingSystem.OnReadyCheck(const Event: TClientGameEvent);
begin
  if Event.Amount > 0.5 then
    StartConfirm
  else
    EndConfirm;
end;

procedure TClientMatchmakingSystem.Enqueue;
var
  Payload: TBytes;
begin
  if FState <> msIdle then Exit;
  FState := msPending;
  PublishState;
  SetLength(Payload, 1);
  Payload[0] := FPendingPartySize;
  FRpc.SendRequest(rpcQueueJoin, Payload,
    procedure(const ResponsePayload: TBytes)
    begin
      FState := msSearching;
      PublishState;
    end);
end;

procedure TClientMatchmakingSystem.Dequeue;
begin
  if FState <> msSearching then Exit;
  FState := msPending;
  PublishState;
  FRpc.SendRequest(rpcQueueLeave, nil,
    procedure(const ResponsePayload: TBytes)
    begin
      FState := msIdle;
      PublishState;
    end);
end;

procedure TClientMatchmakingSystem.StartConfirm;
begin
  FState := msConfirming;
  PublishState;
end;

procedure TClientMatchmakingSystem.EndConfirm;
begin
  FState := msIdle;
  PublishState;
end;

procedure TClientMatchmakingSystem.SendReadyCheck;
begin
  FRpc.SendRequest(rpcReadyCheck, nil, nil);
end;

procedure TClientMatchmakingSystem.SendReadyCancel;
begin
  FRpc.SendRequest(rpcReadyCancel, nil, nil);
end;

end.
