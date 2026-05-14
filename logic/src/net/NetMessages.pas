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

interface

uses
  SysUtils, Classes;

const
  NET_CH_UNRELIABLE = 0;
  NET_CH_RELIABLE = 1;
  NET_HEADER_SIZE = 7;

type
  TNetMsgType = Byte;

const
  msgInvalid    : TNetMsgType = 0;
  msgJoinReq    : TNetMsgType = 1;
  msgJoinAccept : TNetMsgType = 2;
  msgJoinDeny   : TNetMsgType = 3;
  msgInput      : TNetMsgType = 4;
  msgSnapshot   : TNetMsgType = 5;
  msgSpawn      : TNetMsgType = 6;
  msgDespawn    : TNetMsgType = 7;
  msgEvent      : TNetMsgType = 8;
  msgChat       : TNetMsgType = 9;
  msgPing       : TNetMsgType = 10;
  msgPong       : TNetMsgType = 11;

type
  TNetMsgHeader = packed record
    MsgType: TNetMsgType;
    Sequence: UInt32;
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
  TNetReceiveEvent = procedure(Sender: TObject; const Msg: TNetMessage) of object;

implementation

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

end.
