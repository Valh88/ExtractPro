unit PvPSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, help_types, EntityTypes, WorldTypes, GameConfig, Interfaces, EventBus,
  WorldSystemBase;

type
  TPvPSystem = class(TWorldSystemBase)
  public
    procedure Update(const SecondsPassed: Single); override;
  end;

implementation

uses GameWorld;

function W(Obj: TObject): TGameWorld;
begin
  Result := Obj as TGameWorld;
end;

procedure TPvPSystem.Update(const SecondsPassed: Single);
var
  Data: TGameWorldData;
  i, TargetIdx: Integer;
  TargetDist: Single;
  MyPos: TVector2;
  DamageInfo: TDamageInfo;
  E: TGameEvent;
begin
  Data := W(FWorldObj).Data;
  for i := 0 to High(Data.Players) do
  begin
    if Data.Players[i].Status <> psInRaid then Continue;
    if Data.Players[i].Visual = nil then Continue;

    MyPos := Data.Players[i].Visual.Position;
    TargetIdx := W(FWorldObj).FindAlivePlayer(MyPos, Data.Players[i].Id, TargetDist);
    if TargetIdx = -1 then Continue;
    if TargetDist > Data.Players[i].AttackRange then Continue;

    DamageInfo.Amount := Data.Players[i].Damage * SecondsPassed;
    DamageInfo.DamageType := dtPhysical;
    DamageInfo.SourceId := Data.Players[i].Id;
    Data.Players[TargetIdx].Stats.TakeDamage(DamageInfo);

    if not Data.Players[TargetIdx].Stats.IsAlive then
    begin
      Data.Players[i].Kills := Data.Players[i].Kills + 1;
      Data.Players[TargetIdx].Inventory.Free;
      Data.Players[TargetIdx].Status := psDead;
      E.EventType := gePlayerDied;
      E.EntityId := Data.Players[TargetIdx].Id;
      E.SourceId := Data.Players[i].Id;
      W(FWorldObj).QueueEvent(E);
    end else
    begin
      E.EventType := gePlayerDamaged;
      E.EntityId := Data.Players[TargetIdx].Id;
      E.SourceId := Data.Players[i].Id;
      E.Amount := DamageInfo.Amount;
      W(FWorldObj).QueueEvent(E);
    end;
  end;
end;

end.
