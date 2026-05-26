unit RpcServer;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes,
  RpcTypes;

type
  TRpcHandlerEntry = record
    MsgType: Byte;
    Handler: TRpcHandler;
  end;

  TRpcServer = class
  private
    FHandlers: array of TRpcHandlerEntry;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterHandler(const AMsgType: Byte; const AHandler: TRpcHandler);
    function DispatchRequest(const AMsgType: Byte; const APayload: TBytes;
      const ACorrelationId: TGuid; const ASendReply: TRpcReplyProc): Boolean;
  end;

implementation

{ TRpcServer }

constructor TRpcServer.Create;
begin
  inherited Create;
  FHandlers := nil;
end;

destructor TRpcServer.Destroy;
begin
  FHandlers := nil;
  inherited;
end;

procedure TRpcServer.RegisterHandler(const AMsgType: Byte; const AHandler: TRpcHandler);
var
  i: Integer;
begin
  for i := 0 to High(FHandlers) do
    if FHandlers[i].MsgType = AMsgType then
    begin
      FHandlers[i].Handler := AHandler;
      Exit;
    end;
  SetLength(FHandlers, Length(FHandlers) + 1);
  FHandlers[High(FHandlers)].MsgType := AMsgType;
  FHandlers[High(FHandlers)].Handler := AHandler;
end;

function TRpcServer.DispatchRequest(const AMsgType: Byte; const APayload: TBytes;
  const ACorrelationId: TGuid; const ASendReply: TRpcReplyProc): Boolean;
var
  i: Integer;
begin
  for i := 0 to High(FHandlers) do
    if FHandlers[i].MsgType = AMsgType then
    begin
      FHandlers[i].Handler(APayload, ACorrelationId, ASendReply);
      Exit(True);
    end;
  Result := False;
end;

end.
