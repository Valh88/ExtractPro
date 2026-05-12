unit WorldSystemBase;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, help_types, EntityTypes, WorldTypes, GameConfig, Interfaces, EventBus;

type
  TWorldSystemBase = class(TInterfacedObject, IWorldSystem)
  protected
    FWorldObj: TObject;
    function GetWorld: TObject;
  public
    constructor Create(const AWorldObj: TObject);
    procedure Update(const SecondsPassed: Single); virtual; abstract;
  end;

implementation

constructor TWorldSystemBase.Create(const AWorldObj: TObject);
begin
  inherited Create;
  FWorldObj := AWorldObj;
end;

function TWorldSystemBase.GetWorld: TObject;
begin
  Result := FWorldObj;
end;

end.