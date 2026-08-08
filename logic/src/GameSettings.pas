unit GameSettings;

{$mode objfpc}{$H+}

interface

uses
  CastleVectors, State, StateMachine;

type
  TServerGameState = (sgsStart, sgsLoading, sgsWaitingPlayers, sgsCountdown, sgsPlaying, sgsFinished);
  TClientGameState = (cgsMainMenu, cgsSettings, cgsPlaying); // в будущем cgsLoading и прочее для клиента
  TServerGameFsm = specialize TStateMachine<TServerGameState>;
  TClientGameFsm = specialize TStateMachine<TClientGameState>;

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

const
  { Минимальная длительность состояния sgsWaitingPlayers.
    Нужна, чтобы клиент успел показать "Ожидание игроков" на чёрном оверлее
    до reveal-анимации сцены (иначе текст мелькает вместе с ней). }
  WaitingPlayersMinSeconds: Single = 2.0;

  { Длительность состояния sgsCountdown (отсчёт перед стартом игры).
    Клиент использует ту же константу для локального рендера цифр. }
  GameStartCountdownSeconds: Single = 3.0;

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
