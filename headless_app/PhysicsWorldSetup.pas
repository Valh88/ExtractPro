{ Shared scene: static box + dynamic sphere. Used by headless and visual builds. }
unit PhysicsWorldSetup;

{$mode objfpc}{$H+}

interface

uses
  CastleVectors, CastleTransform, CastleScene;

{ Builds physics world under Root.
  WithVisuals: add TCastleBox / TCastleSphere meshes (no extra physics) so a windowed build shows shapes. }
procedure BuildPhysicsDemo(const Root: TCastleRootTransform;
  const WithVisuals: Boolean; out Ball: TCastleTransform);
  

implementation

procedure BuildPhysicsDemo(const Root: TCastleRootTransform;
  const WithVisuals: Boolean; out Ball: TCastleTransform);
var
  Ground: TCastleTransform;
  VisBox: TCastleBox;
  VisSphere: TCastleSphere;
begin
  Ground := TCastleTransform.Create(Root);
  Ground.Name := 'Ground';
  Ground.AddBehavior(TCastleRigidBody.Create(Ground));
  Ground.RigidBody.Dynamic := False;
  Ground.AddBehavior(TCastleBoxCollider.Create(Ground));
  TCastleBoxCollider(Ground.Collider).AutoSize := False;
  TCastleBoxCollider(Ground.Collider).Size := Vector3(20, 0.4, 20);
  Ground.Translation := Vector3(0, 0, 0);

  Ball := TCastleTransform.Create(Root);
  Ball.Name := 'Ball';
  Ball.AddBehavior(TCastleRigidBody.Create(Ball));
  Ball.RigidBody.Dynamic := True;
  Ball.AddBehavior(TCastleSphereCollider.Create(Ball));
  TCastleSphereCollider(Ball.Collider).AutoSize := False;
  TCastleSphereCollider(Ball.Collider).Radius := 0.35;
  TCastleSphereCollider(Ball.Collider).Mass := 1;
  Ball.Translation := Vector3(0, 2.5, 0);

  Root.Add(Ground);
  Root.Add(Ball);

  if WithVisuals then
  begin
    VisBox := TCastleBox.Create(Ground);
    VisBox.Size := Vector3(20, 0.4, 20);
    VisBox.Collides := False;
    VisBox.Pickable := False;
    Ground.Add(VisBox);

    VisSphere := TCastleSphere.Create(Ball);
    VisSphere.Radius := 0.35;
    VisSphere.Collides := False;
    VisSphere.Pickable := False;
    Ball.Add(VisSphere);
  end;
end;

end.
