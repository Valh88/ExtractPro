unit ClientMatchmakingSystem;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes,
  LobbySystemBase, LobbyWorld, NetMessages, RpcClient,
  EventBus;

type
  TMatchmakingState = (msIdle, msSearching);

  TClientMatchmakingSystem = class(TLobbySystemBase)
  private
    FRpc: TRpcClient;
    FState: TMatchmakingState;
    procedure PublishState;
  public
    constructor Create(ALobbyWorld: TLobbyWorldBase; ARpc: TRpcClient);
    procedure Update(const SecondsPassed: Single); override;
    procedure Enqueue;
    procedure Dequeue;
    property State: TMatchmakingState read FState;
  end;

implementation

constructor TClientMatchmakingSystem.Create(ALobbyWorld: TLobbyWorldBase;
  ARpc: TRpcClient);
begin
  inherited Create(ALobbyWorld);
  FRpc := ARpc;
  FState := msIdle;
end;

procedure TClientMatchmakingSystem.PublishState;
var
  E: TGameEvent;
begin
  E.EventType := geMatchmakingStateChanged;
  E.Amount := 0.0;
  if FState = msSearching then
    E.Amount := 1.0;
  GlobalEventBus.Queue(E);
  GlobalEventBus.Flush;
end;

procedure TClientMatchmakingSystem.Update(const SecondsPassed: Single);
begin
end;

procedure TClientMatchmakingSystem.Enqueue;
begin
  if FState = msSearching then Exit;
  FState := msSearching;
  PublishState;
  FRpc.SendRequest(rpcQueueJoin, nil,
    procedure(const ResponsePayload: TBytes)
    begin
    end);
end;

procedure TClientMatchmakingSystem.Dequeue;
begin
  if FState <> msSearching then Exit;
  FRpc.SendRequest(rpcQueueLeave, nil,
    procedure(const ResponsePayload: TBytes)
    begin
      FState := msIdle;
      PublishState;
    end);
end;

end.
