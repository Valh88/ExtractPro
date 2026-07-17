unit GameViewInventory;

interface

uses Classes,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse;

type
  TViewInventory = class(TCastleView)
  published
    InventoryPanelDesign: TCastleDesign;
  public
    InventoryBg: TCastleImageControl;
    InventoryTitle: TCastleLabel;
    InventoryScroll: TCastleScrollView;
    SlotsGrid: TCastleVerticalGroup;
    Slot00: TCastleImageControl;
    Slot01: TCastleImageControl;
    Slot02: TCastleImageControl;
    Slot03: TCastleImageControl;
    Slot04: TCastleImageControl;
    Slot05: TCastleImageControl;
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
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
  InventoryBg := InventoryPanelDesign.DesignedComponent('InventoryBg') as TCastleImageControl;
  InventoryTitle := InventoryPanelDesign.DesignedComponent('InventoryTitle') as TCastleLabel;
  InventoryScroll := InventoryPanelDesign.DesignedComponent('InventoryScroll') as TCastleScrollView;
  SlotsGrid := InventoryPanelDesign.DesignedComponent('SlotsGrid') as TCastleVerticalGroup;
  Slot00 := InventoryPanelDesign.DesignedComponent('Slot00') as TCastleImageControl;
  Slot01 := InventoryPanelDesign.DesignedComponent('Slot01') as TCastleImageControl;
  Slot02 := InventoryPanelDesign.DesignedComponent('Slot02') as TCastleImageControl;
  Slot03 := InventoryPanelDesign.DesignedComponent('Slot03') as TCastleImageControl;
  Slot04 := InventoryPanelDesign.DesignedComponent('Slot04') as TCastleImageControl;
  Slot05 := InventoryPanelDesign.DesignedComponent('Slot05') as TCastleImageControl;
end;

procedure TViewInventory.Stop;
begin
  inherited;
end;

end.
