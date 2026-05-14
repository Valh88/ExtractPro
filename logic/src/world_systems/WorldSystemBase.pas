unit WorldSystemBase;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Interfaces;

type
  TWorldSystemBase = class(TInterfacedObject, IWorldSystem)
  private
    FGameObj: TObject;
  public
    constructor Create(AWorldObj: TObject);
    property WorldObj: TObject read FGameObj;
    procedure Update(const SecondsPassed: Single); virtual; abstract;
  end;

implementation

constructor TWorldSystemBase.Create(AWorldObj: TObject);
begin
  inherited Create;
  FGameObj := AWorldObj;
end;

end.
