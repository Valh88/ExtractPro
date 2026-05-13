{
  Visual (default): window + viewport, see box + sphere.
  Headless: console, physics only.

  Visual:  castle-engine compile
  Headless: castle-engine compile --compiler-option=-dHEADLESS
}
program headless_app;

{$mode objfpc}{$H+}

{$ifdef HEADLESS}
  {$ifdef MSWINDOWS} {$apptype CONSOLE} {$endif}
{$else}
  {$ifdef MSWINDOWS} {$apptype GUI} {$endif}
{$endif}

uses
  {$IFDEF UNIX} CThreads, {$ENDIF}
  SysUtils, Classes,
  CastleVectors, CastleTransform, CastleScene, CastleUtils,
  PhysicsWorldSetup
  {$ifndef HEADLESS}
  , CastleWindow, CastleViewport
  {$endif}
  ;

{$ifndef HEADLESS}
var
  Window: TCastleWindow;

procedure ApplicationInitialize;
var
  V: TCastleViewport;
  Ball: TCastleTransform;
  Light: TCastleDirectionalLight;
begin
  V := TCastleViewport.Create(Application);
  V.FullSize := true;
  Window.Controls.InsertFront(V);
  BuildPhysicsDemo(V.Items, True, Ball);
  Light := TCastleDirectionalLight.Create(Application);
  Light.Translation := Vector3(4, 12, 6);
  V.Items.Add(Light);
  V.Camera.SetWorldView(
    Vector3(6, 5, 6),
    Vector3(-1, -0.45, -1),
    Vector3(0, 1, 0));
end;
{$endif}

{$ifdef HEADLESS}
var
  WorldRoot: TCastleRootTransform;
  Ball: TCastleTransform;
  Dt: Single;
  Step: Integer;
  RayHit: TRayCastResult;
{$endif}

begin
{$ifdef HEADLESS}
  InternalCastleApplicationMode := appRunning;

  WorldRoot := TCastleRootTransform.Create(nil);
  try
    BuildPhysicsDemo(WorldRoot, False, Ball);

    WriteLn('Physics headless (define HEADLESS): ball falls on static box.');
    Dt := 1 / 60;

    for Step := 1 to 120 do
    begin
      WorldRoot.UpdateIncreaseTime(Dt);

      if (Step mod 20) = 0 then
      begin
        RayHit := WorldRoot.PhysicsRayCast(
          Vector3(0, 5, 0), Vector3(0, -1, 0), 20, nil, AllLayers);
        WriteLn(Format('step %d  ball Y=%.4f  ray_hit=%s  ray_Y=%.4f',
          [Step, Ball.Translation.Y, BoolToStr(RayHit.Hit, True),
           RayHit.Point.Y]));
      end;
    end;

    WriteLn('Done.');
  finally
    FreeAndNil(WorldRoot);
  end;
{$else}
  Application.OnInitialize := @ApplicationInitialize;
  Window := TCastleWindow.Create(Application);
  Application.MainWindow := Window;
  Window.ParseParameters;
  Application.MainWindow.OpenAndRun;
{$endif}
end.
