unit GameInitialize;

interface

implementation

uses
  CastleWindow, CastleLog, CastleUIControls,
  CastleRenderOptions
  {$region 'Castle Initialization Uses'}
  , GameViewMain
  , StartView
  , GameViewLobby
  {$endregion 'Castle Initialization Uses'};

var
  Window: TCastleWindow;

procedure ApplicationInitialize;
begin
  { Filmic tonemapping: смягчает тени и приглушает пересветы,
    чтобы тёмные неосвещённые участки оставались читабельными. }
  CastleRenderOptions.ToneMapping := tmACES;

  Window.Container.LoadSettings('castle-data:/CastleSettings.xml');

  {$region 'Castle View Creation'}
  ViewMain := TViewMain.Create(Application);
  ViewStartView := TViewStartView.Create(Application);
  ViewLobby := TViewLobby.Create(Application);
  {$endregion 'Castle View Creation'}

  Window.Container.View := ViewStartView;
end;

initialization
  Application.OnInitialize := @ApplicationInitialize;

  Window := TCastleWindow.Create(Application);
  Application.MainWindow := Window;

  Window.ParseParameters;
end.
