unit TestCase1;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  Classes, SysUtils, fpcunit, testutils, testregistry,
  RpcTypes, RpcServer, RpcClient;

type

  { TRpcTest — базовые тесты RPC }
  TRpcTest = class(TTestCase)
  private
    FServer: TRpcServer;
    FClient: TRpcClient;
    FResponseOk: Boolean;
    FResponseData: TBytes;
    procedure EchoHandler(const ReqPayload: TBytes;
      const CId: TGuid; const ReplyProc: TRpcReplyProc);
    procedure UppercaseHandler(const ReqPayload: TBytes;
      const CId: TGuid; const ReplyProc: TRpcReplyProc);
    procedure OnResponse(const RespPayload: TBytes);
  published
    procedure Setup; override;
    procedure TearDown; override;
    procedure TestSendAndResponse;
    procedure TestUnknownHandler;
    procedure TestMultipleConcurrentRequests;
    procedure TestMultipleHandlers;
    procedure TestEmptyPayload;
    procedure TestCancelRequest;
  end;

  TRpcReplyStub = class
    ReplyData: TBytes;
    procedure Reply(const RespPayload: TBytes);
  end;

implementation

{ TRpcReplyStub }

procedure TRpcReplyStub.Reply(const RespPayload: TBytes);
begin
  ReplyData := Copy(RespPayload, 0, Length(RespPayload));
end;

{ TRpcTest }

procedure TRpcTest.Setup;
begin
  inherited;
  FServer := TRpcServer.Create;
  FServer.RegisterHandler(100, @EchoHandler);
  FServer.RegisterHandler(200, @UppercaseHandler);
  FClient := TRpcClient.Create;
  FResponseOk := False;
  FResponseData := nil;
end;

procedure TRpcTest.TearDown;
begin
  FreeAndNil(FClient);
  FreeAndNil(FServer);
  inherited;
end;

procedure TRpcTest.EchoHandler(const ReqPayload: TBytes;
  const CId: TGuid; const ReplyProc: TRpcReplyProc);
begin
  ReplyProc(ReqPayload);
end;

procedure TRpcTest.UppercaseHandler(const ReqPayload: TBytes;
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

procedure TRpcTest.OnResponse(const RespPayload: TBytes);
begin
  FResponseData := Copy(RespPayload, 0, Length(RespPayload));
  FResponseOk := True;
end;

procedure TRpcTest.TestSendAndResponse;
var
  CId: TGuid;
  Payload: TBytes;
  Stub: TRpcReplyStub;
begin
  SetLength(Payload, 3);
  Payload[0] := Ord('A'); Payload[1] := Ord('B'); Payload[2] := Ord('C');
  CId := FClient.SendRequest(100, Payload, @OnResponse);

  Stub := TRpcReplyStub.Create;
  FServer.DispatchRequest(100, Payload, CId, @Stub.Reply);

  AssertTrue('client dispatch failed', FClient.DispatchResponse(CId, Stub.ReplyData));
  AssertTrue('callback not called', FResponseOk);
  AssertEquals('length mismatch', 3, Length(FResponseData));
  AssertEquals('A', Chr(FResponseData[0]));
  AssertEquals('B', Chr(FResponseData[1]));
  AssertEquals('C', Chr(FResponseData[2]));
  Stub.Free;
end;

procedure TRpcTest.TestUnknownHandler;
var
  CId: TGuid;
  Handled: Boolean;
  Stub: TRpcReplyStub;
  Payload: TBytes;
begin
  SetLength(Payload, 1); Payload[0] := 1;
  CId := FClient.SendRequest(42, Payload, @OnResponse);
  Stub := TRpcReplyStub.Create;
  Handled := FServer.DispatchRequest(42, Payload, CId, @Stub.Reply);
  AssertFalse('unknown handler should return false', Handled);
  AssertFalse('callback should not be called', FResponseOk);
  Stub.Free;
end;

procedure TRpcTest.TestMultipleConcurrentRequests;
var
  CId1, CId2, CId3: TGuid;
  Payload1, Payload2, Payload3: TBytes;
  Stub1, Stub2, Stub3: TRpcReplyStub;
  Ok1, Ok2, Ok3: Boolean;
begin
  SetLength(Payload1, 1); Payload1[0] := 1;
  SetLength(Payload2, 1); Payload2[0] := 2;
  SetLength(Payload3, 1); Payload3[0] := 3;

  CId1 := FClient.SendRequest(100, Payload1, @OnResponse);
  CId2 := FClient.SendRequest(100, Payload2, @OnResponse);
  CId3 := FClient.SendRequest(100, Payload3, @OnResponse);

  Stub1 := TRpcReplyStub.Create;
  Stub2 := TRpcReplyStub.Create;
  Stub3 := TRpcReplyStub.Create;

  FServer.DispatchRequest(100, Payload1, CId1, @Stub1.Reply);
  FServer.DispatchRequest(100, Payload2, CId2, @Stub2.Reply);
  FServer.DispatchRequest(100, Payload3, CId3, @Stub3.Reply);

  Ok1 := FClient.DispatchResponse(CId1, Stub1.ReplyData);
  Ok2 := FClient.DispatchResponse(CId2, Stub2.ReplyData);
  Ok3 := FClient.DispatchResponse(CId3, Stub3.ReplyData);

  AssertTrue('request 1 not found', Ok1);
  AssertTrue('request 2 not found', Ok2);
  AssertTrue('request 3 not found', Ok3);
  AssertEquals('payload1 wrong', 1, Stub1.ReplyData[0]);
  AssertEquals('payload2 wrong', 2, Stub2.ReplyData[0]);
  AssertEquals('payload3 wrong', 3, Stub3.ReplyData[0]);

  Stub1.Free; Stub2.Free; Stub3.Free;
end;

procedure TRpcTest.TestMultipleHandlers;
var
  CId1, CId2: TGuid;
  Payload: TBytes;
  Stub1, Stub2: TRpcReplyStub;
begin
  SetLength(Payload, 4);
  Payload[0] := Ord('t'); Payload[1] := Ord('e');
  Payload[2] := Ord('s'); Payload[3] := Ord('t');

  CId1 := FClient.SendRequest(100, Payload, @OnResponse);
  CId2 := FClient.SendRequest(200, Payload, @OnResponse);

  Stub1 := TRpcReplyStub.Create;
  Stub2 := TRpcReplyStub.Create;

  FServer.DispatchRequest(100, Payload, CId1, @Stub1.Reply);
  FServer.DispatchRequest(200, Payload, CId2, @Stub2.Reply);

  AssertTrue('echo not found', FClient.DispatchResponse(CId1, Stub1.ReplyData));
  AssertTrue('uppercase not found', FClient.DispatchResponse(CId2, Stub2.ReplyData));

  AssertTrue('echo data mismatch', (Length(Stub1.ReplyData) = 4) and (Stub1.ReplyData[0] = Ord('t')));
  AssertTrue('uppercase data mismatch', (Length(Stub2.ReplyData) = 4) and (Stub2.ReplyData[0] = Ord('T')));

  Stub1.Free; Stub2.Free;
end;

procedure TRpcTest.TestEmptyPayload;
var
  CId: TGuid;
  Stub: TRpcReplyStub;
  EmptyPayload, DummyPayload: TBytes;
begin
  EmptyPayload := nil;
  CId := FClient.SendRequest(100, EmptyPayload, @OnResponse);
  Stub := TRpcReplyStub.Create;
  SetLength(DummyPayload, 1); DummyPayload[0] := 0;
  FServer.DispatchRequest(100, DummyPayload, CId, @Stub.Reply);
  AssertTrue('empty request not found', FClient.DispatchResponse(CId, Stub.ReplyData));
  Stub.Free;
end;

procedure TRpcTest.TestCancelRequest;
var
  CId: TGuid;
  Payload: TBytes;
  Stub: TRpcReplyStub;
begin
  SetLength(Payload, 1); Payload[0] := 99;
  CId := FClient.SendRequest(100, Payload, @OnResponse);
  FClient.Cancel(CId);
  Stub := TRpcReplyStub.Create;
  FServer.DispatchRequest(100, Payload, CId, @Stub.Reply);
  AssertFalse('canceled request should not trigger callback',
    FClient.DispatchResponse(CId, Stub.ReplyData));
  AssertFalse('response should not fire callback', FResponseOk);
  Stub.Free;
end;

initialization
  RegisterTest(TRpcTest);
end.
