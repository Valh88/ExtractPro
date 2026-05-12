unit WorldSystemBase;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, help_types, EntityTypes, WorldTypes, GameConfig, Interfaces, EventBus;

type
  TWorldSystemBase = class(TInterfacedObject, IWorldSystem)
  public
    procedure Update(const SecondsPassed: Single); virtual; abstract;
  end;

implementation

end.
