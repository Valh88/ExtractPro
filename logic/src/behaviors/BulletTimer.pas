unit BulletTimer;

{$mode objfpc}{$H+}

interface

uses
  Classes, CastleTransform, CastleVectors, Interfaces, BehaviorBase, GameWorld, help_types, EntityTypes;

type
  TBulletBehavior = class(TBehaviorBase)
  private
    FTime: Single;
    FMaxTime: Single;
    FEntityId: TEntityId;
    FGameWorld: TGameWorld;
    FOnHit:   TBulletHitEvent;
  public
    constructor Create(AOwner: TComponent; const AEntityId: TEntityId;
      const AMaxTime: Single = 20);
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    procedure OnCollision(const CollisionDetails: TPhysicsCollisionDetails);
    property GameWorld: TGameWorld read FGameWorld write FGameWorld;
    property OnHit: TBulletHitEvent read FOnHit write FOnHit;
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
var
  HitId: TEntityId;
  i: Integer;
  Dmg: TDamageInfo;
begin
  if FTime < 0.1 then Exit;

  HitId := 0;
  if (FGameWorld <> nil) and (CollisionDetails.OtherTransform <> nil) then
    with FGameWorld.Data do
    begin
      for i := 0 to High(Players) do
        if (Players[i].Visual <> nil) and (Players[i].Visual.Transform = CollisionDetails.OtherTransform) then
        begin
          HitId := Players[i].Id;
          Break;
        end;
      if HitId = 0 then
        for i := 0 to High(Enemies) do
          if (Enemies[i].Visual <> nil) and (Enemies[i].Visual.Transform = CollisionDetails.OtherTransform) then
          begin
            HitId := Enemies[i].Id;
            Break;
          end;
    end;

  if HitId <> 0 then
  begin
    Dmg.Amount := 10;
    Dmg.DamageType := dtPhysical;
    Dmg.SourceId := FEntityId;
    if Assigned(FOnHit) then
      FOnHit(HitId, Dmg);
  end;
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
