unit ShotSystem;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes, WorldSystemBase, CastleKeysMouse, CastleVectors, CastleTransform, help_types, Interfaces;

type
  TShotSystem = class(TWorldSystemBase)
  private
    FNextBulletId: TEntityId;
  public
    constructor Create(AWorldObj: TObject);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    function Press(const Event: TInputPressRelease): Boolean; override;
  end;

implementation

uses GameWorld, BulletTimer, GameWorldClient;

{ TShotSystem }

constructor TShotSystem.Create(AWorldObj: TObject);
begin
  inherited Create(AWorldObj);
  FNextBulletId := 1000;
end;

destructor TShotSystem.Destroy;
var
  GW: TGameWorldClient;
  i: Integer;
  Bullet: IGameEntity;
  B: TBulletBehavior;
begin
  GW := WorldObj as TGameWorldClient;
  for i := 0 to High(GW.Data.Bullets) do
  begin
    Bullet := GW.Data.Bullets[i].Visual;
    if Bullet <> nil then
    begin
      B := Bullet.Transform.FindBehavior(TBulletBehavior) as TBulletBehavior;
      if B <> nil then
      begin
        B.OnHit := nil;
        B.GameWorld := nil;
      end;
    end;
  end;
  inherited;
end;

procedure TShotSystem.Update(const SecondsPassed: Single);
begin
end;

function TShotSystem.Press(const Event: TInputPressRelease): Boolean;
var
  GW: TGameWorldClient;
  MainPlayer, Bullet: IGameEntity;
  Cam: TCastleTransform;
  i: Integer;
  CamPos, Dir: CastleVectors.TVector3;
  B: TBulletBehavior;
begin
  Result := False;
  if Event.EventType <> itMouseButton then Exit;
  if not Event.IsMouseButton(buttonLeft) then Exit;

  GW := WorldObj as TGameWorldClient;
  MainPlayer := GW.FindEntity(GW.MainPlayerId);
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

  B := Bullet.Transform.FindBehavior(TBulletBehavior) as TBulletBehavior;
  if B <> nil then
  begin
    B.GameWorld := GW;
    B.OnHit := procedure(const HitEntityId: TEntityId; const Damage: TDamageInfo)
    begin
      WriteLn(HitEntityId);
    end;
  end;

  GW.AddBullet(Bullet, GW.MainPlayerId);
  Result := True;
end;

end.
