program e2e_lobby;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  {$ifdef unix} CThreads, {$endif}
  SysUtils, Classes, DateUtils,
  NetClient, NetMessages, RNL, RpcClient, RpcTypes, help_types;

var
  C: TGameClient;
  Rpc: TRpcClient;
  FJoined: Boolean;
  FReadySent: Boolean;
  FHasStart: Boolean;
  FJoinAccept: Boolean;
  FPartyInfo: Boolean;
  FPlaying: Boolean;
  FDenied: Boolean;
  FPhase2: Boolean;
  FGamePort: Word;
  FGameLobbyId: UInt32;
  FGamePlayerId: UInt32;
  MyId: UInt32;

procedure SendMsg(const M: TNetMessage);
begin
  if C <> nil then
    C.Send(M, NET_CH_RELIABLE);
end;

procedure OnRecv(Sender: TObject; const Msg: TNetMessage);
var
  Spawn: TEntitySpawnData;
  Info: TPartyInfoData;
begin
  case Msg.Header.MsgType of
    msgRpcResponse:
      Rpc.DispatchResponse(Msg.Header.CorrelationId, Msg.Payload);
    msgReadyCheck:
    begin
      WriteLn(Format('[%d] ready check asked', [MyId]));
      Flush(Output);
      if not FReadySent then
      begin
        FReadySent := True;
        Rpc.SendRequest(rpcReadyCheck, nil, nil);
      end;
    end;
    msgReadyCheckEnd:
      WriteLn(Format('[%d] ready end result=%d', [MyId, Msg.Payload[0]]));
    msgStartGame:
    begin
      if Length(Msg.Payload) >= 10 then
      begin
        FGamePort := Msg.Payload[0] or (Msg.Payload[1] shl 8);
        FGameLobbyId := Msg.Payload[2] or (Msg.Payload[3] shl 8)
          or (Msg.Payload[4] shl 16) or (Msg.Payload[5] shl 24);
        FGamePlayerId := Msg.Payload[6] or (Msg.Payload[7] shl 8)
          or (Msg.Payload[8] shl 16) or (Msg.Payload[9] shl 24);
        FHasStart := True;
        WriteLn(Format('[%d] start: port=%d lobby=%d player=%d', [MyId, FGamePort, FGameLobbyId, FGamePlayerId]));
        Flush(Output);
      end;
    end;
    msgJoinAccept:
      if FPhase2 and TEntitySpawnData.FromBytes(Msg.Payload, Spawn) then
      begin
        FJoinAccept := True;
        WriteLn(Format('[%d] JoinAccept entity=%d pos=(%.2f,%.2f,%.2f)', [MyId, Spawn.EntityId, Spawn.PosX, Spawn.PosY, Spawn.PosZ]));
        Flush(Output);
      end;
    msgGameStateChanged:
      if FPhase2 and (Length(Msg.Payload) >= 1) then
      begin
        WriteLn(Format('[%d] GameState=%d', [MyId, Msg.Payload[0]]));
        Flush(Output);
        if Msg.Payload[0] = 3 then
          FPlaying := True;
      end;
    msgPartyInfo:
      if FPhase2 and TPartyInfoData.FromBytes(Msg.Payload, Info) then
      begin
        FPartyInfo := True;
        WriteLn(Format('[%d] PartyInfo team=%d members=%d', [MyId, Info.TeamIndex, Info.MemberCount]));
        Flush(Output);
      end;
    msgJoinDeny:
    begin
      FDenied := True;
      WriteLn(Format('[%d] JoinDeny', [MyId]));
      Flush(Output);
    end;
  end;
end;

procedure OnConnected(Sender: TObject);
var
  Payload: TBytes;
begin
  WriteLn(Format('[%d] lobby connected', [MyId]));
  Flush(Output);
  FJoined := True;
  if not FHasStart then
  begin
    SetLength(Payload, 1);
    Payload[0] := 1;
    Rpc.SendRequest(rpcQueueJoin, Payload, nil);
    WriteLn(Format('[%d] queue join sent', [MyId]));
    Flush(Output);
  end;
end;

procedure OnDisconnected(Sender: TObject);
begin
  WriteLn(Format('[%d] disconnected', [MyId]));
  Flush(Output);
end;

procedure OnGameConnected(Sender: TObject);
var
  J: TJoinReqData;
  M: TNetMessage;
begin
  J.LobbyId := FGameLobbyId;
  J.LobbyPlayerId := FGamePlayerId;
  J.Version := 1;
  M.Init(msgJoinReq, J.ToBytes);
  C.Send(M, NET_CH_RELIABLE);
  WriteLn(Format('[%d] game connected, join sent', [MyId]));
  Flush(Output);
end;

var
  T0: TDateTime;
begin
  if ParamCount < 1 then
  begin
    WriteLn('usage: e2e_lobby <tag>');
    Halt(2);
  end;
  MyId := StrToIntDef(ParamStr(1), 1);
  FHasStart := False;
  FPhase2 := False;
  FJoinAccept := False;
  FPartyInfo := False;
  FPlaying := False;
  FDenied := False;
  FReadySent := False;

  Rpc := TRpcClient.Create;
  C := TGameClient.Create;
  try
    Rpc.SendProc := @SendMsg;
    C.OnConnected := @OnConnected;
    C.OnDisconnected := @OnDisconnected;
    C.OnReceive := @OnRecv;
    C.Connect('::1', 7776);

    T0 := Now;
    while Now < T0 + 30 / 86400 do
    begin
      if C.State <> csDisconnected then
        C.Service();

      if FHasStart and not FPhase2 then
      begin
        FPhase2 := True;
        C.OnConnected := nil;
        C.OnDisconnected := nil;
        C.OnReceive := nil;
        C.Disconnect;
        C.Free;
        C := TGameClient.Create;
        C.OnConnected := @OnGameConnected;
        C.OnDisconnected := @OnDisconnected;
        C.OnReceive := @OnRecv;
        C.Connect('::1', FGamePort);
        WriteLn(Format('[%d] phase2: game connect port=%d', [MyId, FGamePort]));
        Flush(Output);
      end;

      if FPhase2 and FJoinAccept and FPartyInfo and FPlaying then
        Break;
      Sleep(16);
    end;

    WriteLn(Format('[%d] RESULT start=%s joinAccept=%s partyInfo=%s playing=%s denied=%s',
      [MyId, BoolToStr(FHasStart, True), BoolToStr(FJoinAccept, True),
       BoolToStr(FPartyInfo, True), BoolToStr(FPlaying, True), BoolToStr(FDenied, True)]));
    Flush(Output);
  finally
    C.Free;
    Rpc.Free;
  end;
end.
