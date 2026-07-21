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
  TMatchmakingState = (msIdle, msPending, msSearching);

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
  E: TClientGameEvent;
begin
  E.EventType := cgeMatchmakingStateChanged;
  case FState of
    msIdle:     E.Amount := 0.0;
    msPending:  E.Amount := 0.5;
    msSearching: E.Amount := 1.0;
  end;
  GlobalClientEventBus.Queue(E);
  GlobalClientEventBus.Flush;
end;

procedure TClientMatchmakingSystem.Update(const SecondsPassed: Single);
begin
end;

procedure TClientMatchmakingSystem.Enqueue;
begin
  if FState <> msIdle then Exit;
  FState := msPending;
  PublishState;
  FRpc.SendRequest(rpcQueueJoin, nil,
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

end.
