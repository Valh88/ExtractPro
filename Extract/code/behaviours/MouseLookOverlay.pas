unit MouseLookOverlay;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  CastleVectors, CastleUIControls, CastleViewport, CastleTransform, CastleKeysMouse,
  FirstPersonCameraBehavior;

type
  { Оверлей поверх вьюпорта: при скрытом курсоре обрабатывает Motion и вызывает
    Container.MouseLookDelta (мышь в центре), передаёт дельту в FirstPersonCameraBehavior. }
  TMouseLookOverlay = class(TCastleUserInterface)
  private
    FViewport: TCastleViewport;
    FHero: TCastleTransform;
  public
    function Motion(const Event: TInputMotion): Boolean; override;
    property Viewport: TCastleViewport read FViewport write FViewport;
    property Hero: TCastleTransform read FHero write FHero;
  end;

implementation

function TMouseLookOverlay.Motion(const Event: TInputMotion): Boolean;
var
  Beh: TFirstPersonCameraBehavior;
  Delta: TVector2;
begin
  Result := false;
  if (FHero = nil) or (Container = nil) or (FViewport = nil) then Exit;
  Beh := TFirstPersonCameraBehavior(FHero.FindBehavior(TFirstPersonCameraBehavior));
  if (Beh = nil) or Beh.CursorVisible then Exit;
  Delta := Container.MouseLookDelta(Event, FViewport.RenderRect);
  Beh.AddMouseLookDelta(Delta);
  Result := true;
end;

end.

