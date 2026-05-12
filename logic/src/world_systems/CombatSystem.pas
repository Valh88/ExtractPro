unit CombatSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, help_types, EntityTypes, WorldTypes, GameConfig, Interfaces, EventBus,
  WorldSystemBase;

type
  TCombatSystem = class(TWorldSystemBase)
  public
    procedure Update(const SecondsPassed: Single); override;
  end;

implementation

uses GameWorld;

function W(Obj: TObject): TGameWorld;
begin
  Result := Obj as TGameWorld;
end;

procedure TCombatSystem.Update(const SecondsPassed: Single);
var
  Data: TGameWorldData;
  i, PlayerIdx, AliveCount: Integer;
  PlayerDist: Single;
  EnemyPos: TVector2;
  DamageInfo: TDamageInfo;
  E: TGameEvent;
begin
  Data := W(FWorldObj).Data;
  for i := 0 to High(Data.Enemies) do
  begin
    if Data.Enemies[i].AIState <> asAttack then Continue;
    if not Data.Enemies[i].Stats.IsAlive then Continue;
    if Data.Enemies[i].Visual = nil then Continue;

    EnemyPos := Data.Enemies[i].Visual.Position;
    PlayerIdx := W(FWorldObj).FindClosestPlayer(EnemyPos, PlayerDist);
    if PlayerIdx = -1 then Continue;

    DamageInfo.Amount := Data.Enemies[i].Damage * SecondsPassed;
    DamageInfo.DamageType := dtPhysical;
    DamageInfo.SourceId := Data.Enemies[i].Id;
    Data.Players[PlayerIdx].Stats.TakeDamage(DamageInfo);

    if not Data.Players[PlayerIdx].Stats.IsAlive then
    begin
      Data.Players[PlayerIdx].Inventory.Free;
      Data.Players[PlayerIdx].Status := psDead;
      E.EventType := gePlayerDied;
      E.EntityId := Data.Players[PlayerIdx].Id;
      E.SourceId := Data.Enemies[i].Id;
      W(FWorldObj).QueueEvent(E);
    end else
    begin
      E.EventType := gePlayerDamaged;
      E.EntityId := Data.Players[PlayerIdx].Id;
      E.SourceId := Data.Enemies[i].Id;
      E.Amount := DamageInfo.Amount;
      W(FWorldObj).QueueEvent(E);
    end;
  end;

  AliveCount := 0;
  for i := 0 to High(Data.Enemies) do
  begin
    if Data.Enemies[i].Stats.IsAlive then
    begin
      if AliveCount <> i then
        Data.Enemies[AliveCount] := Data.Enemies[i];
      Inc(AliveCount);
    end else
      Data.Enemies[i].LootTable := nil;
  end;
  SetLength(Data.Enemies, AliveCount);
end;

end.
