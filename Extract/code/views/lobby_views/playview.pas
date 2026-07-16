unit PlayView;

interface

uses Classes,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse;

type
  TViewPlayView = class(TCastleView)
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
  ViewPlayView: TViewPlayView;

implementation

constructor TViewPlayView.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/views/lobby_views/playview.castle-user-interface';
end;

procedure TViewPlayView.Start;
begin
  inherited;
  { Executed once when view starts. }
end;

procedure TViewPlayView.Update(const SecondsPassed: Single; var HandleInput: boolean);
begin
  inherited;
  { Executed every frame. }
end;

end.
