unit GameConfig;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, Classes, help_types, EntityTypes;

const
  AUTH_SERVER_DEFAULT_PORT = 8081;
  LOBBY_SERVER_DEFAULT_PORT = 7776;
  GAME_SERVER_DEFAULT_PORT = 7777;

type
  { Глобальный конфиг рейда }
  TGameConfig = record
    { Сеть }
    ServerHost: string;        // адрес сервера (IPv4/IPv6)
    AuthPort: Word;            // порт auth-сервера
    LobbyPort: Word;           // порт лобби (matchmaking)
    GamePort: Word;            // порт игрового мира

    { Время }
    RaidTime: Single;          // макс. длительность рейда (сек)
    ExtractionTime: Single;    // время экстракции (сек)

    { Игроки }
    MaxPlayers: Integer;
    PlayerBaseHealth: Single;
    PlayerBaseSpeed: Single;
    PlayerBaseDamage: Single;
    PlayerAttackRange: Single;

    { Враги }
    EnemyBaseHealth: Single;
    EnemyBaseSpeed: Single;
    EnemyBaseDamage: Single;
    EnemyDetectionRange: Single;
    EnemyAttackRange: Single;

    { Подземелье }
    RoomCount: Integer;
    ConnectionsPerRoom: Integer;
    RoomSize: Single;

    { Спавн }
    SpawnWaveCount: Integer;
    SpawnWaveInterval: Single;

    { Броня (формула: урон * (1 - Armor / (Armor + ArmorFormulaDiv))) }
    ArmorFormulaDiv: Single;

    { Матчмейкинг }
    PartiesPerMatch: Integer;   // сколько отрядов в одном матче
    DefaultPartySize: Byte;     // размер отряда по умолчанию (1 или 3)
    ReadyCheckTimeout: Single;  // таймаут подтверждения готовности (сек)

    procedure Init;
  end;

var
  GlobalConfig: TGameConfig;

implementation

procedure TGameConfig.Init;
begin
  ServerHost := '127.0.0.1';
  AuthPort := AUTH_SERVER_DEFAULT_PORT;
  LobbyPort := LOBBY_SERVER_DEFAULT_PORT;
  GamePort := GAME_SERVER_DEFAULT_PORT;
  RaidTime := 600;
  ExtractionTime := 10;
  MaxPlayers := 8;
  PlayerBaseHealth := 100;
  PlayerBaseSpeed := 5;
  PlayerBaseDamage := 15;
  PlayerAttackRange := 2;
  EnemyBaseHealth := 30;
  EnemyBaseSpeed := 3;
  EnemyBaseDamage := 10;
  EnemyDetectionRange := 8;
  EnemyAttackRange := 1.5;
  RoomCount := 12;
  ConnectionsPerRoom := 2;
  RoomSize := 18;
  SpawnWaveCount := 5;
  SpawnWaveInterval := 2;
  ArmorFormulaDiv := 100;
  PartiesPerMatch := 3;
  DefaultPartySize := 1;
  ReadyCheckTimeout := 30.0;
end;

initialization
  GlobalConfig.Init;
end.
