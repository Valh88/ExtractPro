unit WorldSystemBase;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Interfaces, CastleKeysMouse;

type
  TWorldSystemBase = class(TInterfacedObject, IWorldSystem)
  private
    FGameObj: TObject;
  public
    constructor Create(AWorldObj: TObject);
    property WorldObj: TObject read FGameObj;
    procedure Update(const SecondsPassed: Single); virtual; abstract;
    function Press(const Event: TInputPressRelease): Boolean; virtual;
  end;

implementation

constructor TWorldSystemBase.Create(AWorldObj: TObject);
begin
  inherited Create;
  FGameObj := AWorldObj;
end;

function TWorldSystemBase.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := False;
end;

end.
