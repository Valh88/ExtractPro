unit StartView;

interface

uses Classes,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse;

type
  TViewStartView = class(TCastleView)
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
  ViewStartView: TViewStartView;

implementation

constructor TViewStartView.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/views/startview.castle-user-interface';
end;

procedure TViewStartView.Start;
begin
  inherited;
  { Executed once when view starts. }
end;

procedure TViewStartView.Update(const SecondsPassed: Single; var HandleInput: boolean);
begin
  inherited;
  { Executed every frame. }
end;

end.
