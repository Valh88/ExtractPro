unit BulletTimer;

{$mode objfpc}{$H+}

interface

uses
  Classes, CastleTransform, Interfaces, BehaviorBase, GameWorld, help_types;

type
  TBulletBehavior = class(TBehaviorBase)
  private
    FTime: Single;
    FMaxTime: Single;
    FEntityId: TEntityId;
    FGameWorld: TGameWorld;
    FOnHit: TCollisionEvent;
  public
    constructor Create(AOwner: TComponent; const AEntityId: TEntityId;
      const AMaxTime: Single = 20);
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    procedure OnCollision(const CollisionDetails: TPhysicsCollisionDetails);
    property GameWorld: TGameWorld read FGameWorld write FGameWorld;
    property OnHit: TCollisionEvent read FOnHit write FOnHit;
  end;

implementation

{ TBulletBehavior }

constructor TBulletBehavior.Create(AOwner: TComponent; const AEntityId: TEntityId;
  const AMaxTime: Single = 20);
begin
  inherited Create(AOwner);
  FTime := 0;
  FMaxTime := AMaxTime;
  FEntityId := AEntityId;
end;

procedure TBulletBehavior.OnCollision(const CollisionDetails: TPhysicsCollisionDetails);
begin
  if FTime < 0.1 then Exit;
  if Assigned(FOnHit) then
    FOnHit(CollisionDetails);
  WriteLn('Collision');
  FTime := FMaxTime;
end;

procedure TBulletBehavior.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
begin
  inherited Update(SecondsPassed, RemoveMe);
  FTime := FTime + SecondsPassed;
  if FTime >= FMaxTime then
  begin
    if Parent <> nil then
      Parent.Exists := False;
    if FGameWorld <> nil then
      FGameWorld.QueueDeadEntity(FEntityId);
    RemoveMe := rtRemove;
  end;
end;

end.
