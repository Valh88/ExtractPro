program e2e_game;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  {$ifdef unix} CThreads, {$endif}
  SysUtils, Classes, DateUtils,
  NetClient, NetMessages, RNL, help_types;

var
  C: TGameClient;
  MyId: UInt32;
  FJoinAccept: Boolean;
  FPartyInfo: Boolean;
  FPlaying: Boolean;
  FDenied: Boolean;

procedure OnRecv(Sender: TObject; const Msg: TNetMessage);
var
  Spawn: TEntitySpawnData;
  Info: TPartyInfoData;
begin
  case Msg.Header.MsgType of
    msgJoinAccept:
      if TEntitySpawnData.FromBytes(Msg.Payload, Spawn) then
      begin
        FJoinAccept := True;
        WriteLn(Format('[%d] JoinAccept entity=%d pos=(%.2f,%.2f,%.2f) rot=%.2f',
          [MyId, Spawn.EntityId, Spawn.PosX, Spawn.PosY, Spawn.PosZ, Spawn.RotY]));
        Flush(Output);
      end;
    msgGameStateChanged:
      if Length(Msg.Payload) >= 1 then
      begin
        WriteLn(Format('[%d] GameState=%d', [MyId, Msg.Payload[0]]));
        Flush(Output);
        if Msg.Payload[0] = 3 then
          FPlaying := True;
      end;
    msgPartyInfo:
      if TPartyInfoData.FromBytes(Msg.Payload, Info) then
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
  M: TNetMessage;
  J: TJoinReqData;
begin
  WriteLn(Format('[%d] connected, sending msgJoinReq lobbyPlayerId=%d', [MyId, MyId]));
  Flush(Output);
  J.LobbyId := 99;
  J.LobbyPlayerId := MyId;
  J.Version := 1;
  M.Init(msgJoinReq, J.ToBytes);
  if C <> nil then
    C.Send(M, NET_CH_RELIABLE);
end;

procedure OnDisconnected(Sender: TObject);
begin
  WriteLn(Format('[%d] disconnected', [MyId]));
  Flush(Output);
end;

var
  T0: TDateTime;
begin
  if ParamCount < 1 then
  begin
    WriteLn('usage: e2e_game <playerId> [port]');
    Halt(2);
  end;
  MyId := StrToIntDef(ParamStr(1), 1);
  FJoinAccept := False;
  FPartyInfo := False;
  FPlaying := False;
  FDenied := False;

  C := TGameClient.Create;
  try
    C.OnConnected := @OnConnected;
    C.OnDisconnected := @OnDisconnected;
    C.OnReceive := @OnRecv;
    if ParamCount >= 2 then
      C.Connect('::1', Word(StrToIntDef(ParamStr(2), 7901)))
    else
      C.Connect('::1', 7901);

    T0 := Now;
    while Now < T0 + 12 / 86400 do
    begin
      if C.State <> csDisconnected then
        C.Service();
      Sleep(16);
    end;

    WriteLn(Format('[%d] RESULT joinAccept=%s partyInfo=%s playing=%s denied=%s',
      [MyId, BoolToStr(FJoinAccept, True), BoolToStr(FPartyInfo, True),
       BoolToStr(FPlaying, True), BoolToStr(FDenied, True)]));
    Flush(Output);
  finally
    C.Free;
  end;
end.
