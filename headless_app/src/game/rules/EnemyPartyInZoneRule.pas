unit EnemyPartyInZoneRule;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, CastleLog,
  help_types, ExtractionRule, ServerPartySystem;

type
  { Правило: экстракция отменяется, если в зоне находится игрок
    из вражеской (другой) пати. Одиночный игрок (без пати) считается
    вражеским по отношению к любому извлекающемуся. }
  TEnemyPartyInZoneRule = class(TExtractionRule)
  public
    constructor Create;
    function Evaluate(const Ctx: TExtractionContext): Boolean; override;
  end;

implementation

{ TEnemyPartyInZoneRule }

constructor TEnemyPartyInZoneRule.Create;
begin
  inherited Create('EnemyPartyInZone');
end;

function TEnemyPartyInZoneRule.Evaluate(const Ctx: TExtractionContext): Boolean;
var
  I: Integer;
  MyParty, OtherParty: Integer;
begin
  Result := True;
  if Ctx.PartySystem = nil then
    Exit;
  MyParty := Ctx.PartySystem.PartyIndexOfEntity(Ctx.PlayerId);
  for I := 0 to High(Ctx.ZonePlayers) do
  begin
    if Ctx.ZonePlayers[I] = Ctx.PlayerId then
      Continue;
    OtherParty := Ctx.PartySystem.PartyIndexOfEntity(Ctx.ZonePlayers[I]);
    { Игрок без пати (OtherParty = -1) считается вражеским. }
    if OtherParty <> MyParty then
    begin
      WritelnLog('Server', 'EnemyPartyInZone: player %d blocked by enemy %d in zone %d',
        [Ctx.PlayerId, Ctx.ZonePlayers[I], Ctx.ZoneIndex]);
      Exit(False);
    end;
  end;
end;

end.
