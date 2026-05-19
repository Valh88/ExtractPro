unit WorldSystemBase;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Interfaces, CastleKeysMouse,
  GameWorld;

type
  TWorldSystemBase = class(TInterfacedObject, IWorldSystem)
  private
    FGameObj: TGameWorld;
  public
    constructor Create(AWorldObj: TGameWorld);
    property WorldObj: TGameWorld read FGameObj;
    procedure Update(const SecondsPassed: Single); virtual; abstract;
    function Press(const Event: TInputPressRelease): Boolean; virtual;
  end;

implementation

constructor TWorldSystemBase.Create(AWorldObj: TGameWorld);
begin
  inherited Create;
  FGameObj := AWorldObj;
end;

function TWorldSystemBase.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := False;
end;

end.
