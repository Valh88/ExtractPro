unit ExtractPointSystem;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Contnrs,
  CastleTransform, CastleLog,
  GameWorld, WorldSystemBase, EventBus, EntityTypes, help_types,
  NetMessages, GameConfig, GameSettings,
  ServerPartySystem, ExtractionRule,
  ExtractPointTriggerBehavior;

type
  { Обратный вызов для отправки события зоны в сеть (настраивается из
    RegisterSystems, как SendHitProc у TServerShotSystem). }
  TExtractZoneEventProc = reference to procedure(const ZoneEvent: TExtractZoneEvent);

  TExtractPointSystem = class(TWorldSystemBase)
  private
    FWorldRoot: TCastleAbstractRootTransform;
    FExtractPointHookDone: Boolean;
    FSendZoneEventProc: TExtractZoneEventProc;
    FPartySystem: TServerPartySystem;
    FRules: TObjectList;
    FZonePlayers: array of array of TEntityId;
    FZoneCount: Integer;
    function FindNodeByName(const ARoot: TCastleTransform; const AName: String): TCastleTransform;
    procedure AttachExtractPointBehavior;
    procedure OnExtractPointEnter(const AOtherTransform: TCastleTransform; const AZoneIndex: Byte);
    procedure OnExtractPointExit(const AOtherTransform: TCastleTransform; const AZoneIndex: Byte);
    function PlayerEntityIdByTransform(const ATransform: TCastleTransform): TEntityId;
    procedure SendZoneEvent(const AEntityId: TEntityId; const AZoneIndex: Byte;
      const AEntered: Byte; const APosX, APosY, APosZ: Single);
    procedure AddZonePlayer(const AZoneIndex: Byte; const AEntityId: TEntityId);
    procedure RemoveZonePlayer(const AZoneIndex: Byte; const AEntityId: TEntityId);
    function InZone(const AZoneIndex: Byte; const AEntityId: TEntityId): Boolean;
    function PlayerZone(const AEntityId: TEntityId): Integer;
    function EvaluateRules(const APlayerId: TEntityId; const AZoneIndex: Byte): Boolean;
    procedure CancelExtraction(const APlayerId: TEntityId; const AZoneIndex: Byte);
    function PlayerIndex(const AEntityId: TEntityId): Integer;
  public
    constructor Create(AWorldObj: TGameWorld; const AWorldRoot: TCastleAbstractRootTransform);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    procedure AddRule(const ARule: TExtractionRule);
    property SendZoneEventProc: TExtractZoneEventProc read FSendZoneEventProc write FSendZoneEventProc;
    property PartySystem: TServerPartySystem read FPartySystem write FPartySystem;
    property ZoneCount: Integer read FZoneCount;
  end;

implementation

uses Math;

const
  MaxZones = 3;

{ TExtractPointSystem }

constructor TExtractPointSystem.Create(AWorldObj: TGameWorld;
  const AWorldRoot: TCastleAbstractRootTransform);
begin
  inherited Create(AWorldObj);
  FWorldRoot := AWorldRoot;
  FRules := TObjectList.Create(True);
  FZoneCount := 0;
end;

destructor TExtractPointSystem.Destroy;
begin
  FRules.Free;
  inherited;
end;

function TExtractPointSystem.FindNodeByName(const ARoot: TCastleTransform;
  const AName: String): TCastleTransform;
var
  I: Integer;
begin
  Result := nil;
  if ARoot = nil then
    Exit;
  if ARoot.Name = AName then
    Exit(ARoot);
  for I := 0 to ARoot.Count - 1 do
  begin
    Result := FindNodeByName(ARoot.Items[I], AName);
    if Result <> nil then
      Exit;
  end;
end;

procedure TExtractPointSystem.AttachExtractPointBehavior;
var
  I: Integer;
  NodeName: String;
  Node, Target: TCastleTransform;
  B: TExtractPointTriggerBehavior;
begin
  if FExtractPointHookDone then
    Exit;
  for I := 0 to MaxZones - 1 do
  begin
    if I = 0 then
      NodeName := 'ExtractPoint'
    else
      NodeName := 'ExtractPoint' + IntToStr(I + 1);
    Node := FindNodeByName(FWorldRoot, NodeName);
    if Node = nil then
      Continue;
    if Node is TCastleTransformDesign then
      Target := TCastleTransformDesign(Node).DesignRoot
    else
      Target := Node;
    if Target = nil then
      Continue;
    B := TExtractPointTriggerBehavior.Create(nil);
    B.ZoneIndex := Byte(I);
    B.OnEnter := @OnExtractPointEnter;
    B.OnExit := @OnExtractPointExit;
    Target.AddBehavior(B);
    FZoneCount := I + 1;
    if FZoneCount > Length(FZonePlayers) then
      SetLength(FZonePlayers, FZoneCount);
    WritelnLog('Server', 'ExtractPoint zone %d attached (node=%s)', [I, NodeName]);
  end;
  FExtractPointHookDone := True;
end;

function TExtractPointSystem.PlayerEntityIdByTransform(
  const ATransform: TCastleTransform): TEntityId;
var
  I: Integer;
begin
  if ATransform <> nil then
    for I := 0 to High(WorldObj.Data.Players) do
      if (WorldObj.Data.Players[I].Visual <> nil) and
         (WorldObj.Data.Players[I].Visual.Transform = ATransform) then
        Exit(WorldObj.Data.Players[I].Id);
  Result := 0;
end;

function TExtractPointSystem.PlayerIndex(const AEntityId: TEntityId): Integer;
var
  I: Integer;
begin
  for I := 0 to High(WorldObj.Data.Players) do
    if WorldObj.Data.Players[I].Id = AEntityId then
      Exit(I);
  Result := -1;
end;

procedure TExtractPointSystem.SendZoneEvent(const AEntityId: TEntityId;
  const AZoneIndex: Byte; const AEntered: Byte; const APosX, APosY, APosZ: Single);
var
  ZoneEvent: TExtractZoneEvent;
begin
  if not Assigned(FSendZoneEventProc) then
    Exit;
  ZoneEvent.EntityId := AEntityId;
  ZoneEvent.Entered := AEntered;
  ZoneEvent.ZoneIndex := AZoneIndex;
  ZoneEvent.PosX := APosX;
  ZoneEvent.PosY := APosY;
  ZoneEvent.PosZ := APosZ;
  FSendZoneEventProc(ZoneEvent);
end;

procedure TExtractPointSystem.AddZonePlayer(const AZoneIndex: Byte; const AEntityId: TEntityId);
var
  I: Integer;
begin
  if AZoneIndex >= Length(FZonePlayers) then
    Exit;
  for I := 0 to High(FZonePlayers[AZoneIndex]) do
    if FZonePlayers[AZoneIndex][I] = AEntityId then
      Exit;
  SetLength(FZonePlayers[AZoneIndex], Length(FZonePlayers[AZoneIndex]) + 1);
  FZonePlayers[AZoneIndex][High(FZonePlayers[AZoneIndex])] := AEntityId;
end;

procedure TExtractPointSystem.RemoveZonePlayer(const AZoneIndex: Byte; const AEntityId: TEntityId);
var
  I, Last: Integer;
begin
  if AZoneIndex >= Length(FZonePlayers) then
    Exit;
  for I := 0 to High(FZonePlayers[AZoneIndex]) do
    if FZonePlayers[AZoneIndex][I] = AEntityId then
    begin
      Last := High(FZonePlayers[AZoneIndex]);
      FZonePlayers[AZoneIndex][I] := FZonePlayers[AZoneIndex][Last];
      SetLength(FZonePlayers[AZoneIndex], Last);
      Exit;
    end;
end;

function TExtractPointSystem.InZone(const AZoneIndex: Byte; const AEntityId: TEntityId): Boolean;
var
  I: Integer;
begin
  Result := False;
  if AZoneIndex >= Length(FZonePlayers) then
    Exit;
  for I := 0 to High(FZonePlayers[AZoneIndex]) do
    if FZonePlayers[AZoneIndex][I] = AEntityId then
      Exit(True);
end;

function TExtractPointSystem.PlayerZone(const AEntityId: TEntityId): Integer;
var
  Z: Integer;
begin
  for Z := 0 to High(FZonePlayers) do
    if InZone(Byte(Z), AEntityId) then
      Exit(Z);
  Result := -1;
end;

function TExtractPointSystem.EvaluateRules(const APlayerId: TEntityId;
  const AZoneIndex: Byte): Boolean;
var
  I: Integer;
  Ctx: TExtractionContext;
begin
  Result := True;
  if FRules.Count = 0 then
    Exit;
  Ctx.PlayerId := APlayerId;
  Ctx.ZoneIndex := AZoneIndex;
  Ctx.World := WorldObj;
  Ctx.PartySystem := FPartySystem;
  Ctx.ZonePlayers := nil;
  if AZoneIndex < Length(FZonePlayers) then
    Ctx.ZonePlayers := FZonePlayers[AZoneIndex];
  for I := 0 to FRules.Count - 1 do
    if not TExtractionRule(FRules[I]).Evaluate(Ctx) then
    begin
      WritelnLog('Server', 'ExtractPoint: rule "%s" blocked extraction of player %d in zone %d',
        [TExtractionRule(FRules[I]).Name, APlayerId, AZoneIndex]);
      Exit(False);
    end;
end;

procedure TExtractPointSystem.CancelExtraction(const APlayerId: TEntityId;
  const AZoneIndex: Byte);
var
  Idx: Integer;
  Ev: TGameEvent;
  P: TPlayerData;
begin
  Idx := PlayerIndex(APlayerId);
  if Idx <> -1 then
  begin
    P := WorldObj.Data.Players[Idx];
    P.IsExtracting := False;
    P.ExtractionProgress := 0;
    WorldObj.Data.Players[Idx] := P;
    Ev.EventType := geExtractZoneCancelled;
    Ev.EntityId := APlayerId;
    Ev.SourceId := 0;
    Ev.Amount := 0;
    Ev.Position.X := 0;
    Ev.Position.Y := 0;
    Ev.Data := nil;
    WorldObj.QueueEvent(Ev);
    SendZoneEvent(APlayerId, AZoneIndex, 2, 0, 0, 0);
    WritelnLog('Server', 'ExtractPoint: extraction of player %d in zone %d cancelled',
      [APlayerId, AZoneIndex]);
  end;
end;

procedure TExtractPointSystem.OnExtractPointEnter(const AOtherTransform: TCastleTransform;
  const AZoneIndex: Byte);
var
  Eid: TEntityId;
  Ev: TGameEvent;
  Idx: Integer;
  P: TPlayerData;
  PosX, PosY: Single;
begin
  Eid := PlayerEntityIdByTransform(AOtherTransform);
  if Eid = 0 then
    Exit;
  AddZonePlayer(AZoneIndex, Eid);
  PosX := AOtherTransform.Translation.X;
  PosY := AOtherTransform.Translation.Z;
  SendZoneEvent(Eid, AZoneIndex, 1, PosX, PosY, 0);
  if WorldObj.GameState <> sgsPlaying then
  begin
    WritelnLog('Server', 'ExtractPoint: player %d entered zone %d but game not playing, skip',
      [Eid, AZoneIndex]);
    Exit;
  end;
  if not EvaluateRules(Eid, AZoneIndex) then
    Exit;
  Idx := PlayerIndex(Eid);
  if Idx = -1 then
    Exit;
  P := WorldObj.Data.Players[Idx];
  P.IsExtracting := True;
  P.ExtractionProgress := 0;
  WorldObj.Data.Players[Idx] := P;
  Ev.EventType := geExtractionStarted;
  Ev.EntityId := Eid;
  Ev.SourceId := 0;
  Ev.Amount := 0;
  Ev.Position.X := PosX;
  Ev.Position.Y := PosY;
  Ev.Data := nil;
  WorldObj.QueueEvent(Ev);
  WritelnLog('Server', 'ExtractPoint: player (entity %d) entered zone %d, extraction started',
    [Eid, AZoneIndex]);
end;

procedure TExtractPointSystem.OnExtractPointExit(const AOtherTransform: TCastleTransform;
  const AZoneIndex: Byte);
var
  Eid: TEntityId;
  Ev: TGameEvent;
  Idx: Integer;
  P: TPlayerData;
begin
  Eid := PlayerEntityIdByTransform(AOtherTransform);
  if Eid = 0 then
    Exit;
  RemoveZonePlayer(AZoneIndex, Eid);
  SendZoneEvent(Eid, AZoneIndex, 0, AOtherTransform.Translation.X, AOtherTransform.Translation.Z, 0);
  Idx := PlayerIndex(Eid);
  if Idx <> -1 then
  begin
    P := WorldObj.Data.Players[Idx];
    P.IsExtracting := False;
    P.ExtractionProgress := 0;
    WorldObj.Data.Players[Idx] := P;
  end;
  Ev.EventType := geExtractZoneExited;
  Ev.EntityId := Eid;
  Ev.SourceId := 0;
  Ev.Amount := 0;
  Ev.Position.X := AOtherTransform.Translation.X;
  Ev.Position.Y := AOtherTransform.Translation.Z;
  Ev.Data := nil;
  WorldObj.QueueEvent(Ev);
  WritelnLog('Server', 'ExtractPoint: player (entity %d) left zone %d', [Eid, AZoneIndex]);
end;

procedure TExtractPointSystem.Update(const SecondsPassed: Single);
var
  I, Z: Integer;
  P: TPlayerData;
  Ev: TGameEvent;
begin
  if not FExtractPointHookDone then
    AttachExtractPointBehavior;
  if WorldObj.GameState <> sgsPlaying then
    Exit;
  for I := 0 to High(WorldObj.Data.Players) do
  begin
    P := WorldObj.Data.Players[I];
    if not P.IsExtracting then
      Continue;
    Z := PlayerZone(P.Id);
    if Z < 0 then
    begin
      P.IsExtracting := False;
      P.ExtractionProgress := 0;
      WorldObj.Data.Players[I] := P;
      Continue;
    end;
    if not EvaluateRules(P.Id, Byte(Z)) then
    begin
      CancelExtraction(P.Id, Byte(Z));
      Continue;
    end;
    P.ExtractionProgress := P.ExtractionProgress + SecondsPassed;
    WorldObj.Data.Players[I] := P;
    if P.ExtractionProgress >= GlobalConfig.ExtractionTime then
    begin
      P.IsExtracting := False;
      P.ExtractionProgress := 0;
      P.Status := psExtracted;
      WorldObj.Data.Players[I] := P;
      Ev.EventType := gePlayerExtracted;
      Ev.EntityId := P.Id;
      Ev.SourceId := 0;
      Ev.Amount := 0;
      Ev.Position.X := 0;
      Ev.Position.Y := 0;
      Ev.Data := nil;
      WorldObj.QueueEvent(Ev);
      WritelnLog('Server', 'ExtractPoint: player %d extracted (stub)', [P.Id]);
    end;
  end;
end;

procedure TExtractPointSystem.AddRule(const ARule: TExtractionRule);
begin
  FRules.Add(ARule);
end;

end.
