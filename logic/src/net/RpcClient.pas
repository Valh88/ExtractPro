unit RpcClient;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes,
  RpcTypes, NetMessages;

type
  TRpcSendProc = reference to procedure(const M: TNetMessage);

  TRpcPendingEntry = record
    CId: TGuid;
    Callback: TRpcCallback;
  end;

  TRpcClient = class
  private
    FPending: array of TRpcPendingEntry;
    FSendProc: TRpcSendProc;
    function FindPending(const ACorrelationId: TGuid): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function SendRequest(const AMsgType: Byte; const APayload: TBytes;
      const ACallback: TRpcCallback): TGuid;
    function DispatchResponse(const ACorrelationId: TGuid; const APayload: TBytes): Boolean;
    procedure Cancel(const ACorrelationId: TGuid);
    property SendProc: TRpcSendProc read FSendProc write FSendProc;
  end;

implementation

{ TRpcClient }

constructor TRpcClient.Create;
begin
  inherited Create;
  FPending := nil;
  FSendProc := nil;
end;

destructor TRpcClient.Destroy;
begin
  FPending := nil;
  inherited;
end;

function TRpcClient.FindPending(const ACorrelationId: TGuid): Integer;
begin
  for Result := 0 to High(FPending) do
    if FPending[Result].CId = ACorrelationId then
      Exit;
  Result := -1;
end;

function TRpcClient.SendRequest(const AMsgType: Byte; const APayload: TBytes;
  const ACallback: TRpcCallback): TGuid;
var
  M: TNetMessage;
  Wrapped: TBytes;
  L: Integer;
begin
  CreateGuid(Result);
  L := Length(FPending);
  SetLength(FPending, L + 1);
  FPending[L].CId := Result;
  FPending[L].Callback := ACallback;
  SetLength(Wrapped, 1 + Length(APayload));
  Wrapped[0] := AMsgType;
  if Length(APayload) > 0 then
    Move(APayload[0], Wrapped[1], Length(APayload));
  M.Init(msgRpcRequest, Wrapped);
  M.Header.CorrelationId := Result;
  if Assigned(FSendProc) then
    FSendProc(M);
end;

function TRpcClient.DispatchResponse(const ACorrelationId: TGuid; const APayload: TBytes): Boolean;
var
  Idx: Integer;
  CB: TRpcCallback;
  Last: Integer;
begin
  Idx := FindPending(ACorrelationId);
  Result := Idx >= 0;
  if not Result then Exit;
  CB := FPending[Idx].Callback;
  Last := High(FPending);
  if Idx < Last then
    FPending[Idx] := FPending[Last];
  SetLength(FPending, Last);
  CB(APayload);
end;

procedure TRpcClient.Cancel(const ACorrelationId: TGuid);
var
  Idx: Integer;
  Last: Integer;
begin
  Idx := FindPending(ACorrelationId);
  if Idx >= 0 then
  begin
    Last := High(FPending);
    if Idx < Last then
      FPending[Idx] := FPending[Last];
    SetLength(FPending, Last);
  end;
end;

end.
