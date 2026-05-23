unit ClientOutbox;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, WorldSystemBase, NetMessages,
  ClientPlayerSyncBehavior;

type
  TClientOutbox = class(TWorldSystemBase)
  private
    FQueue: array of TNetMessage;
    FChannels: array of Integer;
    FCount: Integer;
    FSendToProc: TSendMessageProc;
    function FindPlayerStateIdx: Integer;
  public
    procedure Add(const AMsg: TNetMessage; const AChannel: Integer);
    procedure Update(const SecondsPassed: Single); override;
    property SendToProc: TSendMessageProc read FSendToProc write FSendToProc;
  end;

implementation

{ TClientOutbox }

procedure TClientOutbox.Add(const AMsg: TNetMessage; const AChannel: Integer);
var
  Idx: Integer;
begin
  if AMsg.Header.MsgType = msgPlayerState then
  begin
    Idx := FindPlayerStateIdx;
    if Idx >= 0 then
    begin
      FQueue[Idx] := AMsg;
      FChannels[Idx] := AChannel;
      Exit;
    end;
  end;

  if FCount >= Length(FQueue) then
  begin
    SetLength(FQueue, FCount + 4);
    SetLength(FChannels, FCount + 4);
  end;
  FQueue[FCount] := AMsg;
  FChannels[FCount] := AChannel;
  Inc(FCount);
end;

function TClientOutbox.FindPlayerStateIdx: Integer;
begin
  for Result := 0 to FCount - 1 do
    if FQueue[Result].Header.MsgType = msgPlayerState then
      Exit;
  Result := -1;
end;

procedure TClientOutbox.Update(const SecondsPassed: Single);
var
  I: Integer;
begin
  if FCount = 0 then Exit;
  if not Assigned(FSendToProc) then Exit;

  for I := 0 to FCount - 1 do
    FSendToProc(FQueue[I], FChannels[I]);

  FCount := 0;
end;

end.
