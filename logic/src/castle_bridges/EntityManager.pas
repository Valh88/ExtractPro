unit EntityManager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, CastleScene, CastleTransform, CastleVectors, CastleViewport, CastleCameras,
  help_types, Interfaces, EntityBridge,
  CharacterControllerBehavior, FirstPersonCameraBehavior;

type
  TEntityManager = class(TInterfacedObject, IEntityFactory)
  private
    FPlayerUrl: String;
    FEnemyUrl: String;
    FViewport: TCastleViewport;
  public
    constructor Create(const APlayerUrl, AEnemyUrl: String; const AViewport: TCastleViewport);
    function CreateEntity(const AEntityId: TEntityId;
      const AUrl: String): IGameEntity;
    function CreatePlayerEntity(const AEntityId: TEntityId): IGameEntity;
    function CreateMainPlayerEntity(const AEntityId: TEntityId): IGameEntity;
    function CreateEnemyEntity(const AEntityId: TEntityId): IGameEntity;
  end;

implementation

{ TEntityManager }

constructor TEntityManager.Create(const APlayerUrl, AEnemyUrl: String; const AViewport: TCastleViewport);
begin
  inherited Create;
  FPlayerUrl := APlayerUrl;
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
    Transform := Design;
  end else
  begin
    Scene := TCastleScene.Create(nil);
    Scene.Url := AUrl;
    Transform := Scene;
  end;

  Result := TEntityBridge.Create(AEntityId, Transform);
end;

function TEntityManager.CreatePlayerEntity(const AEntityId: TEntityId): IGameEntity;
var 
  Entity: TEntityBridge;
begin
  Result := CreateEntity(AEntityId, FPlayerUrl);
  // Entity := Result as TEntityBridge;
  // (Result as TEntityBridge).Transform.RigidBody.LockRotation := [0, 2];
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

  CharCtrl := TCharacterControllerBehavior.Create(Cylinder);
  CharCtrl.Viewport := FViewport;
  CharCtrl.Camera := HeadCamera;
  CharCtrl.MoveSpeed := 6;
  Cylinder.AddBehavior(CharCtrl);

  if Cylinder.RigidBody <> nil then
    Cylinder.RigidBody.LockRotation := [0, 2];

  CharCtrl := TCharacterControllerBehavior.Create(Cylinder);
  CharCtrl.Viewport := FViewport;
  CharCtrl.Camera := HeadCamera;

  // Cylinder.CastShadows := True;
  Cylinder.AddBehavior(CharCtrl);

  if Cylinder.RigidBody <> nil then
    Cylinder.RigidBody.LockRotation := [0, 2];

  FPSCam := TFirstPersonCameraBehavior.Create(Cylinder);
  FPSCam.Viewport := FViewport;
  FPSCam.Camera := HeadCamera;
  FPSCam.CameraMode := cmFirstPerson;
  FPSCam.CursorVisible := False;
  FPSCam.InvertHorizontalMouseLook := True;
  Cylinder.AddBehavior(FPSCam);

  Result := TEntityBridge.Create(AEntityId, Cylinder, Design); // Cylinder or Design?
end;

end.
