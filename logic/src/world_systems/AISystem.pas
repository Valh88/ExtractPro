unit AISystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, help_types, EntityTypes, WorldTypes, GameConfig, Interfaces, EventBus,
  WorldSystemBase;

type
  TAISystem = class(TWorldSystemBase)
  public
    procedure Update(const SecondsPassed: Single); override;
  end;

implementation

uses GameWorld;

function W(Obj: TObject): TGameWorld;
begin
  Result := Obj as TGameWorld;
end;

procedure TAISystem.Update(const SecondsPassed: Single);
var
  Data: TGameWorldData;
  i, PlayerIdx: Integer;
  PlayerDist: Single;
  EnemyPos, PlayerPos: TVector2;
begin
  Data := W(FWorldObj).Data;
  for i := 0 to High(Data.Enemies) do
  begin
    if not Data.Enemies[i].Stats.IsAlive then Continue;
    if Data.Enemies[i].Visual = nil then Continue;
    EnemyPos := Data.Enemies[i].Visual.Position;

    PlayerIdx := W(FWorldObj).FindClosestPlayer(EnemyPos, PlayerDist);
    if PlayerIdx = -1 then Continue;

    case Data.Enemies[i].AIState of
      asIdle:
        if PlayerDist <= Data.Enemies[i].DetectionRange then
          Data.Enemies[i].AIState := asChase;

      asPatrol:
        if PlayerDist <= Data.Enemies[i].DetectionRange then
          Data.Enemies[i].AIState := asChase;

      asChase:
      begin
        if PlayerDist > Data.Enemies[i].DetectionRange * 1.5 then
        begin
          Data.Enemies[i].AIState := asIdle;
          Continue;
        end;

        if PlayerDist <= Data.Enemies[i].AttackRange then
        begin
          Data.Enemies[i].AIState := asAttack;
          Continue;
        end;

        if Data.Players[PlayerIdx].Visual <> nil then
        begin
          PlayerPos := Data.Players[PlayerIdx].Visual.Position;
          EnemyPos.X := EnemyPos.X + (PlayerPos.X - EnemyPos.X) / PlayerDist *
            Data.Enemies[i].Stats.Speed * SecondsPassed;
          EnemyPos.Y := EnemyPos.Y + (PlayerPos.Y - EnemyPos.Y) / PlayerDist *
            Data.Enemies[i].Stats.Speed * SecondsPassed;
          Data.Enemies[i].Visual.Position := EnemyPos;
        end;
      end;

      asAttack:
      begin
        if PlayerDist > Data.Enemies[i].AttackRange * 1.2 then
          Data.Enemies[i].AIState := asChase;
      end;

      asDead:;
    end;
  end;
end;

end.
