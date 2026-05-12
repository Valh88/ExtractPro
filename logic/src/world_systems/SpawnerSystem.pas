unit SpawnerSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, help_types, EntityTypes, WorldTypes, GameConfig, Interfaces, EventBus,
  WorldSystemBase;

type
  TSpawnWaveData = record
    EnemyCount: Integer;
    Interval: Single;
    Timer: Single;
    RoomIndex: Integer;
  end;

  TSpawnerSystem = class(TWorldSystemBase)
  private
    FWaves: array of TSpawnWaveData;
  public
    procedure AddWave(const RoomIndex, Count: Integer; const Interval: Single);
    procedure Update(const SecondsPassed: Single); override;
  end;

implementation

uses GameWorld;

function W(Obj: TObject): TGameWorld;
begin
  Result := Obj as TGameWorld;
end;

procedure TSpawnerSystem.AddWave(const RoomIndex, Count: Integer; const Interval: Single);
var
  W: TSpawnWaveData;
begin
  W.EnemyCount := Count;
  W.Interval := Interval;
  W.Timer := 0;
  W.RoomIndex := RoomIndex;
  SetLength(FWaves, Length(FWaves) + 1);
  FWaves[High(FWaves)] := W;
end;

procedure TSpawnerSystem.Update(const SecondsPassed: Single);
var
  i: Integer;
begin
  for i := High(FWaves) downto 0 do
  begin
    FWaves[i].Timer := FWaves[i].Timer + SecondsPassed;

    while (FWaves[i].EnemyCount > 0) and
          (FWaves[i].Timer >= FWaves[i].Interval) do
    begin
      W(FWorldObj).SpawnEnemy(FWaves[i].RoomIndex);
      FWaves[i].Timer := FWaves[i].Timer - FWaves[i].Interval;
      Dec(FWaves[i].EnemyCount);
    end;

    if FWaves[i].EnemyCount <= 0 then
    begin
      if i < High(FWaves) then
        FWaves[i] := FWaves[High(FWaves)];
      SetLength(FWaves, Length(FWaves) - 1);
    end;
  end;
end;

end.
