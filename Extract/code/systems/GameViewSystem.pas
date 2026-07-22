unit GameViewSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  CastleWindow, CastleUIControls, CastleControls, CastleKeysMouse,
  Interfaces;

type
  TGameViewSystem = class(TInterfacedObject, IWorldSystem)
  private
    FView: TObject;
    procedure SetView(const AValue: TObject);
  public
    constructor Create(AView: TObject);
    procedure Update(const SecondsPassed: Single);
    function Press(const Event: TInputPressRelease): Boolean;
    property View: TObject read FView write SetView;
  end;

implementation

uses GameViewMain;

type
  TGameViewSystemHelper = class helper for TGameViewSystem
  public
    function GameView: TViewMain;
  end;

{ TGameViewSystemHelper }

function TGameViewSystemHelper.GameView: TViewMain;
begin
  Result := TViewMain(FView);
end;

{ TGameViewSystem }

constructor TGameViewSystem.Create(AView: TObject);
begin
  inherited Create;
  FView := AView;
end;

procedure TGameViewSystem.Update(const SecondsPassed: Single);
begin
end;

function TGameViewSystem.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := False;
end;

procedure TGameViewSystem.SetView(const AValue: TObject);
begin
  FView := AValue;
end;

end.
