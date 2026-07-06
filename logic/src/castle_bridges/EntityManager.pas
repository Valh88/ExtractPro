unit EntityManager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, CastleScene, CastleTransform, CastleVectors, CastleViewport, CastleCameras,
  CastleShapes,
  help_types, Interfaces, EntityBridge, BehaviorBase, BulletTimer,
  CharacterControllerBehavior, FirstPersonCameraBehavior;

type
  TEntityManager = class(TInterfacedObject, IEntityFactory)
  private
    FPlayerUrl: String;
    FConnectedPlayerUrl: String;
    FEnemyUrl: String;
    FViewport: TCastleViewport;
  public
    constructor Create(const APlayerUrl, AConnectedPlayerUrl, AEnemyUrl: String; const AViewport: TCastleViewport);
    function CreateEntity(const AEntityId: TEntityId;
      const AUrl: String): IGameEntity;
    function CreatePlayerEntity(const AEntityId: TEntityId): IGameEntity;
    function CreateMainPlayerEntity(const AEntityId: TEntityId): IGameEntity;
    function CreateEnemyEntity(const AEntityId: TEntityId): IGameEntity;
    function CreateBulletEntity(const AEntityId: TEntityId): IGameEntity;
  end;

implementation

{ TEntityManager }

constructor TEntityManager.Create(const APlayerUrl, AConnectedPlayerUrl, AEnemyUrl: String; const AViewport: TCastleViewport);
begin
  inherited Create;
  FPlayerUrl := APlayerUrl;
  FConnectedPlayerUrl := AConnectedPlayerUrl;
  FEnemyUrl := AEnemyUrl;
  FViewport := AViewport;
end;

function TEntityManager.CreateEntity(const AEntityId: TEntityId;
  const AUrl: String): IGameEntity;
var
  Ext: String;
  Scene: TCastleScene;
  Design: TCastleTransformDesign;
  Transform: TCastleTransform;
begin
  Ext := LowerCase(ExtractFileExt(AUrl));

  if Ext = '.castle-transform' then
  begin
    Design := TCastleTransformDesign.Create(nil);
    Design.Url := AUrl;
    Transform := Design.DesignRoot;
  end else
  begin
    Scene := TCastleScene.Create(nil);
    Scene.Url := AUrl;
    Transform := Scene;
  end;
  Result := TEntityBridge.Create(AEntityId, Transform, Design);
end;

function TEntityManager.CreatePlayerEntity(const AEntityId: TEntityId): IGameEntity;
begin
  Result := CreateEntity(AEntityId, FConnectedPlayerUrl);
  if Result.Transform.RigidBody <> nil then
  begin
    Result.Transform.RigidBody.LockRotation := [0, 1, 2];
  end;
end;

function TEntityManager.CreateEnemyEntity(const AEntityId: TEntityId): IGameEntity;
begin
  Result := CreateEntity(AEntityId, FEnemyUrl);
end;

function TEntityManager.CreateMainPlayerEntity(const AEntityId: TEntityId): IGameEntity;
var
  Design: TCastleTransformDesign;
  Cylinder: TCastleTransform;
  HeadCamera: TCastleCamera;
  VisualRoot: TCastleTransform;
  CharCtrl: TCharacterControllerBehavior;
  FPSCam: TFirstPersonCameraBehavior;
begin
  Design := TCastleTransformDesign.Create(nil);
  Design.Url := FPlayerUrl;
  Cylinder := Design.DesignRoot;
  if Cylinder = nil then
    raise Exception.Create('DesignRoot is nil in ' + FPlayerUrl);
  Cylinder.CastShadows := True;

  HeadCamera := Design.DesignedComponent('HeadCamera', False) as TCastleCamera;
  if HeadCamera <> nil then
  begin
    HeadCamera.Rotation := Vector4(1, 0, 0, 0);
    FViewport.Camera := HeadCamera;
  end;

  VisualRoot := Design.DesignedComponent('VisualRoot', False) as TCastleTransform;

  FPSCam := TFirstPersonCameraBehavior.Create(Cylinder);
  FPSCam.Viewport := FViewport;
  FPSCam.Camera := HeadCamera;
  FPSCam.VisualRoot := VisualRoot;
  FPSCam.CameraMode := cmFirstPerson;
  FPSCam.CursorVisible := False;
  FPSCam.InvertHorizontalMouseLook := False;
  Cylinder.AddBehavior(FPSCam);

  CharCtrl := TCharacterControllerBehavior.Create(Cylinder);
  CharCtrl.Viewport := FViewport;
  CharCtrl.Camera := HeadCamera;
  CharCtrl.MoveSpeed := 6;
  CharCtrl.FirstPersonCam := FPSCam;
  Cylinder.AddBehavior(CharCtrl);

  if Cylinder.RigidBody <> nil then
    Cylinder.RigidBody.LockRotation := [0, 1, 2];

  Result := TEntityBridge.Create(AEntityId, Cylinder, Design);
end;

function TEntityManager.CreateBulletEntity(const AEntityId: TEntityId): IGameEntity;
var
  Sphere: TCastleSphere;
  RB: TCastleRigidBody;
  Collider: TCastleSphereCollider;
  Bullet: TBulletBehavior;
begin
  Sphere := TCastleSphere.Create(nil);
  Sphere.Radius := 0.15;
  Sphere.Color := Vector4(1, 0.8, 0, 1);

  RB := TCastleRigidBody.Create(Sphere);
  RB.Dynamic := True;
  RB.Gravity := False;

  Collider := TCastleSphereCollider.Create(Sphere);
  Collider.Radius := 0.15;

  Sphere.AddBehavior(RB);
  Sphere.AddBehavior(Collider);

  Bullet := TBulletBehavior.Create(Sphere, AEntityId);
  RB.OnCollisionEnter := @Bullet.OnCollision;
  Sphere.AddBehavior(Bullet);

  Result := TEntityBridge.Create(AEntityId, Sphere);
end;

end.
