unit GameViewLobby;

interface

uses
  SysUtils, Classes,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse,
  LobbyClient;

type
  TViewLobby = class(TCastleView)
  published
    { Components designed using CGE editor.
      These fields will be automatically initialized at Start. }
    // ButtonXxx: TCastleButton;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: boolean); override;
    function Press(const Event: TInputPressRelease): Boolean; override;
    procedure SetLobbyClient(const AValue: TLobbyClient);
  private
    FLobbyClient: TLobbyClient;
  end;

var
  ViewLobby: TViewLobby;

implementation

constructor TViewLobby.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/views/gameviewlobby.castle-user-interface';
end;

procedure TViewLobby.Start;
begin
  inherited;
end;

procedure TViewLobby.Stop;
begin
  FreeAndNil(FLobbyClient);
  inherited;
end;

procedure TViewLobby.Update(const SecondsPassed: Single; var HandleInput: boolean);
begin
  inherited;
  if FLobbyClient <> nil then
    FLobbyClient.Update(SecondsPassed);
end;

function TViewLobby.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited;
  if Result then Exit;
  if FLobbyClient <> nil then
    Result := FLobbyClient.Press(Event);
end;

procedure TViewLobby.SetLobbyClient(const AValue: TLobbyClient);
begin
  FLobbyClient := AValue;
end;

end.
