unit ServerAuthSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  WorldSystemBase, GameWorld, AuthTypes, AuthServer;

type
  TServerAuthSystem = class(TWorldSystemBase)
  private
    FAuth: TAuthServer;
    FValidator: IAuthValidator;
  public
    constructor Create(AWorldObj: TGameWorld; APort: Word);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    property Validator: IAuthValidator read FValidator;
  end;

implementation

{ TServerAuthSystem }

constructor TServerAuthSystem.Create(AWorldObj: TGameWorld; APort: Word);
begin
  inherited Create(AWorldObj);
  FAuth := TAuthServer.Create(APort);
  FAuth.Start;
  FValidator := FAuth.Validator;
end;

destructor TServerAuthSystem.Destroy;
begin
  FValidator := nil;
  FAuth.Stop;
  FAuth.Free;
  inherited;
end;

procedure TServerAuthSystem.Update(const SecondsPassed: Single);
begin
end;

end.