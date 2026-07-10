unit GameViewLobby;

interface

uses Classes,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse;

type
  TViewLobby = class(TCastleView)
  published
    { Components designed using CGE editor.
      These fields will be automatically initialized at Start. }
    // ButtonXxx: TCastleButton;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: boolean); override;
  end;

var
  ViewLobby: TViewLobby;

implementation

constructor TViewLobby.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/gameviewlobby.castle-user-interface';
end;

procedure TViewLobby.Start;
begin
  inherited;
  { Executed once when view starts. }
end;

procedure TViewLobby.Update(const SecondsPassed: Single; var HandleInput: boolean);
begin
  inherited;
  { Executed every frame. }
end;

end.
