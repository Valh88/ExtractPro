unit ClientMatchmakingSystem;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes,
  LobbySystemBase, LobbyWorld, NetMessages, RpcClient;

type
  TMatchmakingState = (msIdle, msSearching);

  TClientMatchmakingSystem = class(TLobbySystemBase)
  private
    FRpc: TRpcClient;
    FState: TMatchmakingState;
    FOnStateChanged: TNotifyEvent;
  public
    constructor Create(ALobbyWorld: TLobbyWorldBase; ARpc: TRpcClient);
    procedure Update(const SecondsPassed: Single); override;
    procedure Enqueue;
    procedure Dequeue;
    property State: TMatchmakingState read FState;
    property OnStateChanged: TNotifyEvent read FOnStateChanged write FOnStateChanged;
  end;

implementation

constructor TClientMatchmakingSystem.Create(ALobbyWorld: TLobbyWorldBase;
  ARpc: TRpcClient);
begin
  inherited Create(ALobbyWorld);
  FRpc := ARpc;
  FState := msIdle;
end;

procedure TClientMatchmakingSystem.Update(const SecondsPassed: Single);
begin
end;

procedure TClientMatchmakingSystem.Enqueue;
begin
  if FState = msSearching then Exit;
  FState := msSearching;
  FRpc.SendRequest(rpcQueueJoin, nil,
    procedure(const ResponsePayload: TBytes)
    begin
      if Assigned(FOnStateChanged) then FOnStateChanged(Self);
    end);
  if Assigned(FOnStateChanged) then FOnStateChanged(Self);
end;

procedure TClientMatchmakingSystem.Dequeue;
begin
  if FState <> msSearching then Exit;
  FRpc.SendRequest(rpcQueueLeave, nil,
    procedure(const ResponsePayload: TBytes)
    begin
      FState := msIdle;
      if Assigned(FOnStateChanged) then FOnStateChanged(Self);
    end);
end;

end.
