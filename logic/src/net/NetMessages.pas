{
  NetMessages.pas — игровые типы сетевых пакетов и сериализация.

  ── Каналы RNL ─────────────────────────────────────────────────────
    NET_CH_UNRELIABLE = 0  — ненадёжный канал (позиции, инпуты)
    NET_CH_RELIABLE   = 1  — надёжный канал   (спавн, ивенты, чат)

  ── Формат пакета ──────────────────────────────────────────────────
    [TNetMsgHeader 7 байт][Payload N байт]
      MsgType: Byte — тип сообщения (msgJoinReq, msgInput, ...)
      Sequence: UInt32 — порядковый номер
      PayloadLen: UInt16 — длина полезных данных

  ── Типы сообщений ─────────────────────────────────────────────────
    msgJoinReq / msgJoinAccept / msgJoinDeny — подключение
    msgInput        — ввод игрока (движение, действие)
    msgSnapshot     — полное состояние мира (сервер → клиент)
    msgSpawn        — создание сущности
    msgDespawn      — удаление сущности
    msgEvent        — игровое событие (урон, смерть, экстракция)
    msgChat         — чат

  ── Использование ──────────────────────────────────────────────────
    var M: TNetMessage;
    M.Init(msgChat, [Byte(Ord('H')), Byte(Ord('i'))]);
    Bytes := M.Pack;                          // → TBytes
    if TNetMessage.Unpack(Bytes, M) then ...  // ← TBytes

  ── Зависимости ────────────────────���───────────────────────────────
    SysUtils, Classes
}
unit NetMessages;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes;

const
  NET_CH_UNRELIABLE = 0;
  NET_CH_RELIABLE = 1;

type
  TNetMsgType = Byte;

  TEntitySpawnData = packed record
    EntityId: UInt32;
    PosX, PosY, PosZ: Single;
    RotY: Single;
    function ToBytes: TBytes;
    class function FromBytes(const Data: TBytes; out Value: TEntitySpawnData): Boolean; static;
  end;

  TPlayerStateData = packed record
    EntityId: UInt32;
    PosX, PosY, PosZ: Single;
    RotY: Single;
    Pitch: Single;
    Jump: Byte;
    function ToBytes: TBytes;
    class function FromBytes(const Data: TBytes; out Value: TPlayerStateData): Boolean; static;
  end;

const
  msgInvalid     = 0;
  msgJoinReq     = 1;
  msgJoinAccept  = 2;
  msgJoinDeny    = 3;
  msgInput       = 4;
  msgSnapshot    = 5;
  msgSpawn       = 6;
  msgDespawn     = 7;
  msgEvent       = 8;
  msgChat        = 9;
  msgPing        = 10;
  msgPong        = 11;
  msgPlayerState = 12;
  msgShot        = 13;
  msgHit         = 14;
  msgAuth        = 15;
  msgRpcRequest  = 16;
  msgRpcResponse = 17;
  msgRoomList     = 18;
  msgRoomListRequest = 19;
  msgJoinRaid     = 20;
  msgJoinRaidAccept = 21;
  msgJoinRaidDeny = 22;
  msgReadyCheck = 23;       // server→client: показать панель готовности
  msgReadyCheckUpdate = 24; // server→client: статус готовности игроков
  msgReadyCheckEnd = 25;    // server→client: ready check завершён (0=rollback, 1=game start)
  msgStartGame = 26;        // server→client: порт game server для подключения
  msgGameStateChanged = 27; // server→client: текущее состояние TServerGameState (payload: 1 byte)
  msgPartyInfo = 28;        // server→client: состав пати (TPartyInfoData)
  msgExtractZone = 29;      // server→client: игрок вошёл/вышел из зоны эвакуации (TExtractZoneEvent)

  rpcQueueJoin  = 30;
  rpcQueueLeave = 31;
  rpcReadyCheck = 32;
  rpcReadyCancel = 33;

type
  TJoinReqData = packed record
    LobbyId: UInt32;
    LobbyPlayerId: UInt32;
    Version: Byte;
    function ToBytes: TBytes;
    class function FromBytes(const Data: TBytes; out Value: TJoinReqData): Boolean; static;
  end;

  TPartyInfoData = record
    TeamIndex: Byte;
    MemberCount: Byte;
    MemberIds: array of UInt32;
    function ToBytes: TBytes;
    class function FromBytes(const Data: TBytes; out Value: TPartyInfoData): Boolean; static;
  end;

  TAuthPayload = packed record
    Token: array[0..63] of AnsiChar;
    function ToBytes: TBytes;
    class function FromBytes(const Data: TBytes; out Value: TAuthPayload): Boolean; static;
  end;

type
  TShotData = packed record
    OwnerEntityId: UInt32;
    OriginX, OriginY, OriginZ: Single;
    DirX, DirY, DirZ: Single;
    function ToBytes: TBytes;
    class function FromBytes(const Data: TBytes; out Value: TShotData): Boolean; static;
  end;

  THitData = packed record
    TargetEntityId: UInt32;
    DamageAmount: Single;
    SourceEntityId: UInt32;
    function ToBytes: TBytes;
    class function FromBytes(const Data: TBytes; out Value: THitData): Boolean; static;
  end;

  { Событие зоны эвакуации: игрок (EntityId) вошёл (Entered=1), вышел (Entered=0)
    или извлечение отменено правилом (Entered=2) в зоне ZoneIndex.
    Позиция — точка входа/выхода. }
  TExtractZoneEvent = packed record
    EntityId: UInt32;
    Entered: Byte;
    ZoneIndex: Byte;
    PosX, PosY, PosZ: Single;
    function ToBytes: TBytes;
    class function FromBytes(const Data: TBytes; out Value: TExtractZoneEvent): Boolean; static;
  end;

type
  TSnapshotEntry = packed record
    EntityId: UInt32;
    EntityType: Byte;
    PosX, PosY, PosZ, RotY: Single;
    Pitch: Single;
    Jump: Byte;
  end;

  TSnapshotData = record
    ServerTime: Double;
    Seq: UInt32;
    Entries: array of TSnapshotEntry;
    function ToBytes: TBytes;
    class function FromBytes(const Data: TBytes; out Value: TSnapshotData): Boolean; static;
  end;

type
  TNetMsgHeader = packed record
    MsgType: TNetMsgType;
    Sequence: UInt32;
    CorrelationId: TGuid;
    PayloadLen: UInt16;
  end;

  { Helper to build/send/receive network messages }
  TNetMessage = record
    Header: TNetMsgHeader;
    Payload: TBytes;
    procedure Init(AMsgType: TNetMsgType; const APayload: array of Byte); overload;
    procedure Init(AMsgType: TNetMsgType); overload;
    function Pack: TBytes;
    class function ReadHeader(const Data: TBytes; out OutHeader: TNetMsgHeader): Boolean; static;
    class function Unpack(const Data: TBytes; out Msg: TNetMessage): Boolean; static;
  end;

  { Event fired when server receives a message }
  TNetReceiveEvent = reference to procedure(Sender: TObject; const Msg: TNetMessage);

implementation

{ TEntitySpawnData }

function TEntitySpawnData.ToBytes: TBytes;
begin
  SetLength(Result, SizeOf(TEntitySpawnData));
  Move(Self, Result[0], SizeOf(TEntitySpawnData));
end;

class function TEntitySpawnData.FromBytes(const Data: TBytes; out Value: TEntitySpawnData): Boolean;
begin
  Result := Length(Data) >= SizeOf(TEntitySpawnData);
  if not Result then Exit;
  Move(Data[0], Value, SizeOf(TEntitySpawnData));
end;

{ TPlayerStateData }

function TPlayerStateData.ToBytes: TBytes;
begin
  SetLength(Result, SizeOf(TPlayerStateData));
  Move(Self, Result[0], SizeOf(TPlayerStateData));
end;

class function TPlayerStateData.FromBytes(const Data: TBytes; out Value: TPlayerStateData): Boolean;
begin
  Result := Length(Data) >= SizeOf(TPlayerStateData);
  if not Result then Exit;
  Move(Data[0], Value, SizeOf(TPlayerStateData));
end;

{ TShotData }

function TShotData.ToBytes: TBytes;
begin
  SetLength(Result, SizeOf(TShotData));
  Move(Self, Result[0], SizeOf(TShotData));
end;

class function TShotData.FromBytes(const Data: TBytes; out Value: TShotData): Boolean;
begin
  Result := Length(Data) >= SizeOf(TShotData);
  if not Result then Exit;
  Move(Data[0], Value, SizeOf(TShotData));
end;

{ THitData }

function THitData.ToBytes: TBytes;
begin
  SetLength(Result, SizeOf(THitData));
  Move(Self, Result[0], SizeOf(THitData));
end;

class function THitData.FromBytes(const Data: TBytes; out Value: THitData): Boolean;
begin
  Result := Length(Data) >= SizeOf(THitData);
  if not Result then Exit;
  Move(Data[0], Value, SizeOf(THitData));
end;

{ TExtractZoneEvent }

function TExtractZoneEvent.ToBytes: TBytes;
begin
  SetLength(Result, SizeOf(TExtractZoneEvent));
  Move(Self, Result[0], SizeOf(TExtractZoneEvent));
end;

class function TExtractZoneEvent.FromBytes(const Data: TBytes; out Value: TExtractZoneEvent): Boolean;
begin
  Result := Length(Data) >= SizeOf(TExtractZoneEvent);
  if not Result then Exit;
  Move(Data[0], Value, SizeOf(TExtractZoneEvent));
end;

{ TSnapshotData }

function TSnapshotData.ToBytes: TBytes;
var
  Count: UInt16;
  EntrySize, I, Off: Integer;
begin
  Count := Length(Entries);
  EntrySize := SizeOf(TSnapshotEntry);
  Off := SizeOf(ServerTime) + SizeOf(Seq) + SizeOf(Count);
  SetLength(Result, Off + Count * EntrySize);
  Move(ServerTime, Result[0], SizeOf(ServerTime));
  Move(Seq, Result[SizeOf(ServerTime)], SizeOf(Seq));
  Move(Count, Result[SizeOf(ServerTime) + SizeOf(Seq)], SizeOf(Count));
  for I := 0 to Count - 1 do
    Move(Entries[I], Result[Off + I * EntrySize], EntrySize);
end;

class function TSnapshotData.FromBytes(const Data: TBytes; out Value: TSnapshotData): Boolean;
var
  Count: UInt16;
  I, EntrySize, Off: Integer;
begin
  EntrySize := SizeOf(TSnapshotEntry);
  Off := SizeOf(Value.ServerTime) + SizeOf(Value.Seq) + SizeOf(Count);
  Result := Length(Data) >= Off;
  if not Result then Exit;
  Move(Data[0], Value.ServerTime, SizeOf(Value.ServerTime));
  Move(Data[SizeOf(Value.ServerTime)], Value.Seq, SizeOf(Value.Seq));
  Move(Data[SizeOf(Value.ServerTime) + SizeOf(Value.Seq)], Count, SizeOf(Count));
  SetLength(Value.Entries, Count);
  for I := 0 to Count - 1 do
  begin
    if Off + EntrySize > Length(Data) then
    begin
      SetLength(Value.Entries, I);
      Exit(False);
    end;
    Move(Data[Off + I * EntrySize], Value.Entries[I], EntrySize);
  end;
end;

{ TNetMessage }

procedure TNetMessage.Init(AMsgType: TNetMsgType; const APayload: array of Byte);
begin
  Header.MsgType := AMsgType;
  Header.Sequence := 0;
  Header.PayloadLen := Length(APayload);
  SetLength(Payload, Length(APayload));
  if Length(APayload) > 0 then
    Move(APayload[0], Payload[0], Length(APayload));
end;

procedure TNetMessage.Init(AMsgType: TNetMsgType);
begin
  Header.MsgType := AMsgType;
  Header.Sequence := 0;
  Header.PayloadLen := 0;
  Payload := nil;
end;

function TNetMessage.Pack: TBytes;
begin
  SetLength(Result, SizeOf(TNetMsgHeader) + Length(Payload));
  Header.PayloadLen := Length(Payload);
  Move(Header, Result[0], SizeOf(TNetMsgHeader));
  if Length(Payload) > 0 then
    Move(Payload[0], Result[SizeOf(TNetMsgHeader)], Length(Payload));
end;

class function TNetMessage.ReadHeader(const Data: TBytes; out OutHeader: TNetMsgHeader): Boolean;
begin
  Result := Length(Data) >= SizeOf(TNetMsgHeader);
  if not Result then Exit;
  Move(Data[0], OutHeader, SizeOf(TNetMsgHeader));
end;

class function TNetMessage.Unpack(const Data: TBytes; out Msg: TNetMessage): Boolean;
begin
  Result := Length(Data) >= SizeOf(TNetMsgHeader);
  if not Result then Exit;
  Move(Data[0], Msg.Header, SizeOf(TNetMsgHeader));
  SetLength(Msg.Payload, Msg.Header.PayloadLen);
  if Msg.Header.PayloadLen > 0 then
    Move(Data[SizeOf(TNetMsgHeader)], Msg.Payload[0], Msg.Header.PayloadLen);
end;

{ TJoinReqData }

function TJoinReqData.ToBytes: TBytes;
begin
  SetLength(Result, SizeOf(TJoinReqData));
  Move(Self, Result[0], SizeOf(TJoinReqData));
end;

class function TJoinReqData.FromBytes(const Data: TBytes; out Value: TJoinReqData): Boolean;
begin
  Result := Length(Data) >= SizeOf(TJoinReqData);
  if not Result then Exit;
  Move(Data[0], Value, SizeOf(TJoinReqData));
end;

{ TPartyInfoData }

function TPartyInfoData.ToBytes: TBytes;
var
  Off, I: Integer;
begin
  Off := 2;
  SetLength(Result, Off + Length(MemberIds) * 4);
  Result[0] := TeamIndex;
  Result[1] := Byte(Length(MemberIds));
  for I := 0 to High(MemberIds) do
  begin
    Result[Off + I * 4] := Byte(MemberIds[I]);
    Result[Off + I * 4 + 1] := Byte(MemberIds[I] shr 8);
    Result[Off + I * 4 + 2] := Byte(MemberIds[I] shr 16);
    Result[Off + I * 4 + 3] := Byte(MemberIds[I] shr 24);
  end;
end;

class function TPartyInfoData.FromBytes(const Data: TBytes; out Value: TPartyInfoData): Boolean;
var
  Count, Off, I: Integer;
begin
  Result := Length(Data) >= 2;
  if not Result then Exit;
  Value.TeamIndex := Data[0];
  Count := Data[1];
  Value.MemberCount := Count;
  Off := 2;
  if Length(Data) < Off + Count * 4 then
    Exit(False);
  SetLength(Value.MemberIds, Count);
  for I := 0 to Count - 1 do
    Value.MemberIds[I] := Data[Off + I * 4] or (Data[Off + I * 4 + 1] shl 8) or
      (Data[Off + I * 4 + 2] shl 16) or (Data[Off + I * 4 + 3] shl 24);
end;

{ TAuthPayload }

function TAuthPayload.ToBytes: TBytes;
begin
  SetLength(Result, SizeOf(TAuthPayload));
  Move(Self, Result[0], SizeOf(TAuthPayload));
end;

class function TAuthPayload.FromBytes(const Data: TBytes; out Value: TAuthPayload): Boolean;
begin
  Result := Length(Data) >= SizeOf(TAuthPayload);
  if not Result then Exit;
  Move(Data[0], Value, SizeOf(TAuthPayload));
end;

end.
