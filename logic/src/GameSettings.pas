unit GameSettings;

{$mode objfpc}{$H+}

interface

uses
  CastleVectors;

type
  TSpawnPoint = record
    Pos: TVector3;
    RotY: Single;
  end;

  TTeamSpawnSet = record
    Name: string;
    Points: array of TSpawnPoint;
  end;

  TMapUrls = record
    Render: string;
    Headless: string;
  end;

  TGameSettings = record
    MapUrl: TMapUrls;
    SpawnPoints: array of TSpawnPoint;
    TeamSpawnSets: array of TTeamSpawnSet;
    MaxPlayersPerTeam: Byte;
  end;

  PGameSettings = ^TGameSettings;

{ Конвенция маркеров в .castle-transform (невидимые TCastleTransform):
  - "Spawn_1", "Spawn_2"        - общий пул точек спавна (без группы)
  - "Spawn_Alpha_1"             - группа "Alpha", её точка спавна
  - Позиция = Translation, поворот = Rotation (ось Y).
  Если в дизайне найдены маркеры Spawn_* - они заменяют
  программно заданные SpawnPoints/TeamSpawnSets. }
function DefaultGameSettings: TGameSettings;

implementation

function DefaultGameSettings: TGameSettings;
begin
  Result.MapUrl.Render := 'castle-data:/physics_scene.castle-transform';
  Result.MapUrl.Headless := 'castle-data:/physics_scene_headless.castle-transform';
  Result.MaxPlayersPerTeam := 0;
  SetLength(Result.SpawnPoints, 1);
  Result.SpawnPoints[0].Pos := Vector3(0, 5, 0);
  Result.SpawnPoints[0].RotY := 0;
end;

end.
