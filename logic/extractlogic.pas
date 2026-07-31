{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit ExtractLogic;

{$warn 5023 off : no warning about unused units}
interface

uses
  Interfaces, EntityTypes, WorldTypes, GameWorld, LobbyWorld, GameConfig, 
  GameSettings, EntityBridge, WorldBridge, EventBus, help_types, 
  EntityManager, CharacterControllerBehavior, FirstPersonCameraBehavior, 
  MouseLookOverlay, TouchMoveControl, WorldSystemBase, LobbySystemBase, 
  JobQueueSystem, JobQueue, RNL, NetMessages, NetServer, NetClient, AuthTypes, 
  AuthServer, AuthClient, BulletTimer, GameWorldClient, ClientGameStates, 
  DbAccounts, DbItems, DbSession, DbConfig, DbCore, Db, State, StateMachine, 
  LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('ExtractLogic', @Register);
end.
