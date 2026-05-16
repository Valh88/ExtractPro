unit ShotSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, WorldSystemBase, CastleKeysMouse, CastleVectors, CastleTransform, help_types, Interfaces;

type
  TShotSystem = class(TWorldSystemBase)
  private
    FNextBulletId: TEntityId;
  public
    constructor Create(AWorldObj: TObject);
    procedure Update(const SecondsPassed: Single); override;
    function Press(const Event: TInputPressRelease): Boolean; override;
  end;

implementation

uses GameWorld;

{ TShotSystem }

constructor TShotSystem.Create(AWorldObj: TObject);
begin
  inherited Create(AWorldObj);
  FNextBulletId := 1000;
end;

procedure TShotSystem.Update(const SecondsPassed: Single);
begin
end;

function TShotSystem.Press(const Event: TInputPressRelease): Boolean;
var
  GW: TGameWorld;
  MainPlayer, Bullet: IGameEntity;
  Cam: TCastleTransform;
  i: Integer;
  CamPos, Dir: CastleVectors.TVector3;
begin
  Result := False;
  if Event.EventType <> itMouseButton then Exit;
  if not Event.IsMouseButton(buttonLeft) then Exit;

  GW := WorldObj as TGameWorld;
  MainPlayer := GW.FindEntity(42);
  if MainPlayer = nil then Exit;

  Cam := nil;
  for i := 0 to MainPlayer.Transform.Count - 1 do
    if MainPlayer.Transform.Items[i].Name = 'HeadCamera' then
    begin
      Cam := MainPlayer.Transform.Items[i];
      Break;
    end;
  if Cam = nil then Exit;

  CamPos := Cam.WorldTranslation;
  Dir := Cam.WorldDirection;

  Bullet := GW.Factory.CreateBulletEntity(FNextBulletId);
  Inc(FNextBulletId);
  Bullet.Transform.Translation := CamPos + Dir * 1.0;
  Bullet.Transform.RigidBody.LinearVelocity := Dir * 20;

  GW.World.RegisterEntity(Bullet);
  Result := True;
end;

end.
