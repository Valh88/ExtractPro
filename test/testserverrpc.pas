unit TestServerRpc;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  Classes, SysUtils, fpcunit, testutils, testregistry,
  RpcTypes, RpcServer;

type

  { TServerRpcTest — тесты серверной части RPC }
  TServerRpcTest = class(TTestCase)
  private
    FServer: TRpcServer;
    FReplyData: TBytes;
    FReplyOk: Boolean;
    procedure EchoHandler(const ReqPayload: TBytes;
      const CId: TGuid; const ReplyProc: TRpcReplyProc);
    procedure UppercaseHandler(const ReqPayload: TBytes;
      const CId: TGuid; const ReplyProc: TRpcReplyProc);
    procedure CaptureReply(const RespPayload: TBytes);
  published
    procedure Setup; override;
    procedure TearDown; override;
    procedure TestRegisterAndDispatch;
    procedure TestUnknownHandler;
    procedure TestMultipleHandlers;
    procedure TestHandlerOverwrite;
    procedure TestReplyPayload;
  end;

  TRpcReplyCatcher = class
    Data: TBytes;
    Called: Boolean;
    procedure Reply(const RespPayload: TBytes);
  end;

implementation

{ TRpcReplyCatcher }

procedure TRpcReplyCatcher.Reply(const RespPayload: TBytes);
begin
  Data := Copy(RespPayload, 0, Length(RespPayload));
  Called := True;
end;

{ TServerRpcTest }

procedure TServerRpcTest.Setup;
begin
  inherited;
  FServer := TRpcServer.Create;
  FServer.RegisterHandler(100, @EchoHandler);
  FServer.RegisterHandler(200, @UppercaseHandler);
  FReplyData := nil;
  FReplyOk := False;
end;

procedure TServerRpcTest.TearDown;
begin
  FreeAndNil(FServer);
  inherited;
end;

procedure TServerRpcTest.EchoHandler(const ReqPayload: TBytes;
  const CId: TGuid; const ReplyProc: TRpcReplyProc);
begin
  ReplyProc(ReqPayload);
end;

procedure TServerRpcTest.UppercaseHandler(const ReqPayload: TBytes;
  const CId: TGuid; const ReplyProc: TRpcReplyProc);
var
  i: Integer;
  Upper: TBytes;
begin
  SetLength(Upper, Length(ReqPayload));
  for i := 0 to High(ReqPayload) do
    if ReqPayload[i] in [Ord('a')..Ord('z')] then
      Upper[i] := ReqPayload[i] - 32
    else
      Upper[i] := ReqPayload[i];
  ReplyProc(Upper);
end;

procedure TServerRpcTest.CaptureReply(const RespPayload: TBytes);
begin
  FReplyData := Copy(RespPayload, 0, Length(RespPayload));
  FReplyOk := True;
end;

procedure TServerRpcTest.TestRegisterAndDispatch;
var
  CId: TGuid;
  Payload: TBytes;
  Catcher: TRpcReplyCatcher;
begin
  SetLength(Payload, 3);
  Payload[0] := Ord('A'); Payload[1] := Ord('B'); Payload[2] := Ord('C');
  FillChar(CId, SizeOf(CId), 0);

  Catcher := TRpcReplyCatcher.Create;
  AssertTrue('dispatch failed', FServer.DispatchRequest(100, Payload, CId, @Catcher.Reply));
  AssertTrue('reply not called', Catcher.Called);
  AssertEquals('length mismatch', 3, Length(Catcher.Data));
  AssertEquals('A', Chr(Catcher.Data[0]));
  Catcher.Free;
end;

procedure TServerRpcTest.TestUnknownHandler;
var
  CId: TGuid;
  Payload: TBytes;
  Catcher: TRpcReplyCatcher;
begin
  SetLength(Payload, 1); Payload[0] := 1;
  FillChar(CId, SizeOf(CId), 0);
  Catcher := TRpcReplyCatcher.Create;
  AssertFalse('unknown handler should return false',
    FServer.DispatchRequest(42, Payload, CId, @Catcher.Reply));
  AssertFalse('reply should not be called', Catcher.Called);
  Catcher.Free;
end;

procedure TServerRpcTest.TestMultipleHandlers;
var
  CId1, CId2: TGuid;
  Payload: TBytes;
  Catcher1, Catcher2: TRpcReplyCatcher;
begin
  SetLength(Payload, 4);
  Payload[0] := Ord('t'); Payload[1] := Ord('e');
  Payload[2] := Ord('s'); Payload[3] := Ord('t');
  FillChar(CId1, SizeOf(CId1), 0);
  FillChar(CId2, SizeOf(CId2), 0);

  Catcher1 := TRpcReplyCatcher.Create;
  Catcher2 := TRpcReplyCatcher.Create;

  AssertTrue('echo dispatch failed', FServer.DispatchRequest(100, Payload, CId1, @Catcher1.Reply));
  AssertTrue('uppercase dispatch failed', FServer.DispatchRequest(200, Payload, CId2, @Catcher2.Reply));

  AssertTrue('echo not called', Catcher1.Called);
  AssertTrue('uppercase not called', Catcher2.Called);
  AssertEquals('echo data', 'test', Chr(Catcher1.Data[0]) + Chr(Catcher1.Data[1]) +
    Chr(Catcher1.Data[2]) + Chr(Catcher1.Data[3]));
  AssertEquals('uppercase data', 'TEST', Chr(Catcher2.Data[0]) + Chr(Catcher2.Data[1]) +
    Chr(Catcher2.Data[2]) + Chr(Catcher2.Data[3]));

  Catcher1.Free; Catcher2.Free;
end;

procedure TServerRpcTest.TestHandlerOverwrite;
var
  CId: TGuid;
  Payload: TBytes;
  Catcher: TRpcReplyCatcher;
begin
  SetLength(Payload, 1); Payload[0] := 42;
  FillChar(CId, SizeOf(CId), 0);

  FServer.RegisterHandler(100,
    procedure(const ReqPayload: TBytes; const CId: TGuid; const ReplyProc: TRpcReplyProc)
    begin
      SetLength(FReplyData, 1);
      FReplyData[0] := 99;
      ReplyProc(FReplyData);
    end);

  Catcher := TRpcReplyCatcher.Create;
  AssertTrue('dispatch failed', FServer.DispatchRequest(100, Payload, CId, @Catcher.Reply));
  AssertTrue('reply not called', Catcher.Called);
  AssertEquals('overwritten handler data', 99, Catcher.Data[0]);
  Catcher.Free;
end;

procedure TServerRpcTest.TestReplyPayload;
var
  Payload, BigPayload: TBytes;
  CId: TGuid;
  Catcher: TRpcReplyCatcher;
  i: Integer;
begin
  SetLength(BigPayload, 1000);
  for i := 0 to 999 do
    BigPayload[i] := Byte(i mod 256);
  FillChar(CId, SizeOf(CId), 0);

  Catcher := TRpcReplyCatcher.Create;
  AssertTrue('dispatch failed', FServer.DispatchRequest(100, BigPayload, CId, @Catcher.Reply));
  AssertTrue('reply not called', Catcher.Called);
  AssertEquals('length mismatch', 1000, Length(Catcher.Data));
  AssertEquals('byte 0', 0, Catcher.Data[0]);
  AssertEquals('byte 999', 231, Catcher.Data[999]);
  Catcher.Free;
end;

initialization
  RegisterTest(TServerRpcTest);
end.
