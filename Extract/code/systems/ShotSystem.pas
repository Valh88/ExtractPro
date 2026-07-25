unit ShotSystem;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes, WorldSystemBase, CastleKeysMouse, CastleVectors, CastleTransform, help_types, Interfaces, GameWorld,
  ClientOutbox, NetMessages, CastleLog;

type
  TShotSystem = class(TWorldSystemBase)
  private
    FNextBulletId: TEntityId;
    FOutbox: TClientOutbox;
  public
    constructor Create(AWorldObj: TGameWorld);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    function Press(const Event: TInputPressRelease): Boolean; override;
    property Outbox: TClientOutbox read FOutbox write FOutbox;
  end;

implementation

uses BulletTimer, GameWorldClient;

{ TShotSystem }

constructor TShotSystem.Create(AWorldObj: TGameWorld);
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
  Bullet: IGameEntity;
  Cam: TCastleCamera;
  CamPos, Dir: CastleVectors.TVector3;
  B: TBulletBehavior;
  ShotData: TShotData;
  M: TNetMessage;
begin
  Result := False;
  if Event.EventType <> itMouseButton then Exit;
  if not Event.IsMouseButton(buttonLeft) then Exit;

  GW := WorldObj as TGameWorldClient;
  if GW.Viewport = nil then Exit;
  Cam := GW.Viewport.Camera;
  if Cam = nil then Exit;

  CamPos := Cam.WorldTranslation;
  Dir := Cam.WorldDirection;

  Bullet := GW.Factory.CreateBulletEntity(FNextBulletId);
  Inc(FNextBulletId);
  Bullet.Transform.Translation := CamPos + Dir * 3.0;
  Bullet.Transform.RigidBody.LinearVelocity := Dir * 20;

  B := Bullet.Transform.FindBehavior(TBulletBehavior) as TBulletBehavior;
  if B <> nil then
  begin
    B.GameWorld := GW;
    B.OnHit := procedure(const HitEntityId: TEntityId; const Damage: TDamageInfo)
    begin
      WritelnLog('Shot', 'Hit entity: %d', [HitEntityId]);
    end;
  end;

  GW.AddBullet(Bullet, GW.MainPlayerId);
  Result := True;

  ShotData.OwnerEntityId := GW.MainPlayerId;
  ShotData.OriginX := CamPos.X;
  ShotData.OriginY := CamPos.Y;
  ShotData.OriginZ := CamPos.Z;
  ShotData.DirX := Dir.X;
  ShotData.DirY := Dir.Y;
  ShotData.DirZ := Dir.Z;
  M.Init(msgShot, ShotData.ToBytes);
  if Assigned(FOutbox) then
    FOutbox.Add(M, NET_CH_UNRELIABLE);
end;

end.
