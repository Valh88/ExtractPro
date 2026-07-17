unit GameViewInventory;

interface

uses Classes,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse;

type
  TViewInventory = class(TCastleView)
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
  ViewInventory: TViewInventory;

implementation

constructor TViewInventory.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/views/lobby_view/gameviewinventory.castle-user-interface';
end;

procedure TViewInventory.Start;
begin
  inherited;
  { Executed once when view starts. }
end;

procedure TViewInventory.Update(const SecondsPassed: Single; var HandleInput: boolean);
begin
  inherited;
  { Executed every frame. }
end;

end.
