unit RpcTypes;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes;

type
  TRpcCallback = reference to procedure(const ResponsePayload: TBytes);
  TRpcReplyProc = procedure(const RespPayload: TBytes) of object;
  TRpcHandler = reference to procedure(const RequestPayload: TBytes;
    const CorrelationId: TGuid; const ReplyProc: TRpcReplyProc);

implementation

end.
