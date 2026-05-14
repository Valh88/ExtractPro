{
  ┌─────────────────────────────────────────────────────────────────────┐
  │                      ExtractPro Server                             │
  ├─────────────────────────────────────────────────────────────────────┤
  │                                                                     │
  │  ── Режимы сборки ───────────────────────────────────────────────── │
  │                                                                     │
  │    castle-engine compile                        headless (default)  │
  │    castle-engine compile --compiler-option=-dVISUAL   окно + физика │
  │                                                                     │
  │  ── Команды запуска (headless) ────────────────────��─────────────── │
  │                                                                     │
  │    ./ExtractProServer                           порт 7777, 8 слотов │
  │    ./ExtractProServer --port=8888               порт 8888           │
  │    ./ExtractProServer --max-players=16          до 16 игроков       │
  │    ./ExtractProServer --port=9001 --max-players=4                   │
  │                                                                     │
  │  ── Визуальный режим (-dVISUAL) ─────────────────────────────────── │
  │                                                                     │
  │    Запускает TCastleWindow со вьюпортом + физическая сцена.         │
  │    Сервер автоматически стартует на порту 7777.                     │
  │    LabelStatus показывает количество подключённых игроков.          │
  │    WASD + мышь — свободный полёт по сцене (CGE examine navigation).│
  │    Подключиться: отдельный экземпляр Extract/клиента.              │
  │                                                                     │
  │  ── Сетевая архитектура ─────────────────────────────────────────── │
  │                                                                     │
  │    TGameServer (NetServer.pas)          ←──  RNL (UDP)              │
  │      │  OnConnect + OnDisconnect + OnReceive                        │
  │      │                                                              │
  │    TGameWorld (GameWorld.pas)           игровая логика              │
  │      │  AISystem, CombatSystem, ...                                 │
  │                                                                     │
  │    Пакеты: TNetMessage с msg* типом (NetMessages.pas)               │
  │                                                                     │
  │  ── Зависимости ─────────────────────────────────────────────────── │
  │    RNL, help_types, EntityTypes, WorldTypes, GameWorld,             │
  │    GameConfig, WorldBridge, NetServer, NetMessages                  │
  │                                                                     │
  └─────────────────────────────────────────────────────────────────────┘
}

program headless_app;

{$mode objfpc}{$H+}

{$ifdef VISUAL}
  {$ifdef MSWINDOWS} {$apptype GUI} {$endif}
{$else}
  {$ifdef MSWINDOWS} {$apptype CONSOLE} {$endif}
  {$define HEADLESS}
{$endif}

uses
  {$IFDEF UNIX} CThreads, {$ENDIF}
  SysUtils, Classes
  {$ifdef VISUAL}
  , CastleVectors, CastleTransform, CastleScene, CastleUtils, CastleParameters,
  CastleWindow, CastleViewport, CastleUIControls, CastleControls,
  GameViewServerTest, ServerEntityFactory, GameServerApp
  {$else}
  , CastleVectors, CastleTransform, CastleScene,
  GameServerApp
  {$endif}
  ;

{$ifdef VISUAL}
var
  Window: TCastleWindow;

procedure ApplicationInitialize;
begin
  ViewServerTest := TViewServerTest.Create(Application);
  Window.Container.View := ViewServerTest;
end;
{$endif}

begin
{$ifdef HEADLESS}
  TGameServerApp.RunApp(
    // procedure(const App: TGameServerApp)
    // begin
    //   WriteLn('Hello from headless app');
    //   Flush(Output);
      
    // end
  );
{$else}
  Application.OnInitialize := @ApplicationInitialize;
  Window := TCastleWindow.Create(Application);
  Application.MainWindow := Window;
  Window.ParseParameters;
  Application.MainWindow.OpenAndRun;
{$endif}
end.
