unit BulletTimer;

{$mode objfpc}{$H+}

interface

uses
  Classes, CastleTransform, Interfaces, BehaviorBase;

type
  TBulletBehavior = class(TBehaviorBase)
  private
    FTime: Single;
    FMaxTime: Single;
    FOnHit: TCollisionEvent;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    procedure OnCollision(const CollisionDetails: TPhysicsCollisionDetails);
    property OnHit: TCollisionEvent read FOnHit write FOnHit;
  end;

implementation

{ TBulletBehavior }

constructor TBulletBehavior.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTime := 0;
  FMaxTime := 20;
end;

procedure TBulletBehavior.OnCollision(const CollisionDetails: TPhysicsCollisionDetails);
var
  RB: TCastleRigidBody;
begin
  if Assigned(FOnHit) then
    FOnHit(CollisionDetails);
  writeLn('OnCollision: ');
end;

procedure TBulletBehavior.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
begin
  inherited Update(SecondsPassed, RemoveMe);
  FTime := FTime + SecondsPassed;
  if FTime >= FMaxTime then
  begin
    if Parent <> nil then
      Parent.Exists := False;
  end;
end;

end.
