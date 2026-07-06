unit ServerShotSystem;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes, WorldSystemBase, GameWorld, NetMessages,
  CastleTransform, CastleVectors, Interfaces, help_types;

type
  TSendHitToPlayerProc = reference to procedure(const APlayerId: UInt32; const HitData: THitData);

  TServerShotSystem = class(TWorldSystemBase)
  private
    FSendHitProc: TSendHitToPlayerProc;
  public
    procedure QueueShot(const ShotData: TShotData; AOwnerPlayerId: UInt32);
    procedure Update(const SecondsPassed: Single); override;
    property SendHitProc: TSendHitToPlayerProc read FSendHitProc write FSendHitProc;
  end;

implementation

uses BulletTimer;

{ TServerShotSystem }

procedure TServerShotSystem.Update(const SecondsPassed: Single);
begin
end;

procedure TServerShotSystem.QueueShot(const ShotData: TShotData; AOwnerPlayerId: UInt32);
var
  Bullet: IGameEntity;
  B: TBulletBehavior;
  OwnerPlayerId: UInt32;
  OwnerEntityId: UInt32;
begin
  OwnerPlayerId := AOwnerPlayerId;
  OwnerEntityId := ShotData.OwnerEntityId;
  Bullet := WorldObj.Factory.CreateBulletEntity(WorldObj.AllocateEntityId);
  Bullet.Transform.Translation := Vector3(ShotData.OriginX, ShotData.OriginY, ShotData.OriginZ)
    + Vector3(ShotData.DirX, ShotData.DirY, ShotData.DirZ) * 1.0;
  Bullet.Transform.RigidBody.LinearVelocity := Vector3(ShotData.DirX, ShotData.DirY, ShotData.DirZ) * 20;

  B := Bullet.Transform.FindBehavior(TBulletBehavior) as TBulletBehavior;
  if B <> nil then
  begin
    B.GameWorld := WorldObj;
    B.OnHit := procedure(const HitEntityId: TEntityId; const Damage: TDamageInfo)
    var
      HitData: THitData;
    begin
      if not Assigned(FSendHitProc) then Exit;
      HitData.TargetEntityId := HitEntityId;
      HitData.DamageAmount := Damage.Amount;
      HitData.SourceEntityId := OwnerEntityId;
      FSendHitProc(OwnerPlayerId, HitData);
    end;
  end;

  WorldObj.AddBullet(Bullet, ShotData.OwnerEntityId);
end;

end.