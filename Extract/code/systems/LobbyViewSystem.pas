unit LobbyViewSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  CastleKeysMouse, Interfaces;

type
  TLobbyViewTab = (lvtPlay, lvtLoadouts, lvtHeroes, lvtMarket);

  TLobbyViewSystem = class(TInterfacedObject, IWorldSystem)
  private
    FView: TObject;
    FActiveTab: TLobbyViewTab;
    procedure SetActiveTab(const ATab: TLobbyViewTab);
  public
    constructor Create(AView: TObject);
    procedure Update(const SecondsPassed: Single);
    function Press(const Event: TInputPressRelease): Boolean;
    property ActiveTab: TLobbyViewTab read FActiveTab write SetActiveTab;
    property View: TObject read FView write FView;
  end;

implementation

uses GameViewLobby;

type
  TLobbyViewSystemHelper = class helper for TLobbyViewSystem
  public
    function LobbyView: TViewLobby;
  end;

{ TLobbyViewSystemHelper }

function TLobbyViewSystemHelper.LobbyView: TViewLobby;
begin
  Result := TViewLobby(FView);
end;

{ TLobbyViewSystem }

constructor TLobbyViewSystem.Create(AView: TObject);
begin
  inherited Create;
  FView := AView;
  FActiveTab := lvtPlay;
end;

procedure TLobbyViewSystem.Update(const SecondsPassed: Single);
begin
end;

function TLobbyViewSystem.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := False;
end;

procedure TLobbyViewSystem.SetActiveTab(const ATab: TLobbyViewTab);
begin
  FActiveTab := ATab;
end;

end.
