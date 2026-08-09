unit ExtractPointTriggerBehavior;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  CastleTransform;

type
  { Колбек срабатывания триггера зоны. AOtherTransform — трансформ, вошедший в зону }
  TExtractPointTriggerEvent = procedure(const AOtherTransform: TCastleTransform) of object;

  { Поведение зоны эвакуации: подписывается на события физики своего RigidBody
    (триггер шлёт обычные OnCollisionEnter/OnCollisionExit) и транслирует их
    наружу через OnEnter/OnExit. Игровой логики не знает. }
  TExtractPointTriggerBehavior = class(TCastleBehavior)
  private
    FRigidBody: TCastleRigidBody;
    FOnEnter: TExtractPointTriggerEvent;
    FOnExit: TExtractPointTriggerEvent;
    procedure HookRigidBody;
    procedure HandleEnter(const CollisionDetails: TPhysicsCollisionDetails);
    procedure HandleExit(const CollisionDetails: TPhysicsCollisionDetails);
  protected
    procedure ParentAfterAttach; override;
    procedure WorldAfterAttach; override;
    procedure WorldBeforeDetach; override;
  public
    property OnEnter: TExtractPointTriggerEvent read FOnEnter write FOnEnter;
    property OnExit: TExtractPointTriggerEvent read FOnExit write FOnExit;
  end;

implementation

{ TExtractPointTriggerBehavior }

procedure TExtractPointTriggerBehavior.HookRigidBody;
begin
  if FRigidBody = nil then
    FRigidBody := Parent.FindBehavior(TCastleRigidBody) as TCastleRigidBody;
  if FRigidBody <> nil then
  begin
    FRigidBody.OnCollisionEnter := @HandleEnter;
    FRigidBody.OnCollisionExit := @HandleExit;
  end;
end;

procedure TExtractPointTriggerBehavior.ParentAfterAttach;
begin
  inherited ParentAfterAttach;
  HookRigidBody;
end;

procedure TExtractPointTriggerBehavior.WorldAfterAttach;
begin
  inherited WorldAfterAttach;
  HookRigidBody;
end;

procedure TExtractPointTriggerBehavior.WorldBeforeDetach;
begin
  if FRigidBody <> nil then
  begin
    FRigidBody.OnCollisionEnter := nil;
    FRigidBody.OnCollisionExit := nil;
  end;
  inherited WorldBeforeDetach;
end;

procedure TExtractPointTriggerBehavior.HandleEnter(const CollisionDetails: TPhysicsCollisionDetails);
begin
  if Assigned(FOnEnter) then
    FOnEnter(CollisionDetails.OtherTransform);
end;

procedure TExtractPointTriggerBehavior.HandleExit(const CollisionDetails: TPhysicsCollisionDetails);
begin
  if Assigned(FOnExit) then
    FOnExit(CollisionDetails.OtherTransform);
end;

end.
