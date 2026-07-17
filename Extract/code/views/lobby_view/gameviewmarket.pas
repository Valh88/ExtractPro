unit GameViewMarket;

interface

uses Classes, SysUtils,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse, CastleColors;

type
  TMarketItemData = record
    Name: string;
    ItemType: string;
    Description: string;
    Price: Integer;
  end;

  TViewMarket = class(TCastleView)
  published
    MarketDesign: TCastleDesign;
  public
    MarketBg: TCastleImageControl;
    MarketTitle: TCastleLabel;
    SearchEdit: TCastleEdit;
    FindBtn: TCastleButton;
    ItemsScroll: TCastleScrollView;
    ItemsList: TCastleVerticalGroup;
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
    procedure AddItemRow(const AData: TMarketItemData);
    procedure ClearItems;
  end;

var
  ViewMarket: TViewMarket;

implementation

constructor TViewMarket.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/views/lobby_view/gameviewmarket.castle-user-interface';
end;

procedure TViewMarket.Start;
begin
  inherited;
  MarketDesign := DesignedComponent('MarketDesign') as TCastleDesign;
  MarketBg := MarketDesign.DesignedComponent('MarketBg') as TCastleImageControl;
  MarketTitle := MarketDesign.DesignedComponent('MarketTitle') as TCastleLabel;
  SearchEdit := MarketDesign.DesignedComponent('SearchEdit') as TCastleEdit;
  FindBtn := MarketDesign.DesignedComponent('FindBtn') as TCastleButton;
  ItemsScroll := MarketDesign.DesignedComponent('ItemsScroll') as TCastleScrollView;
  ItemsList := MarketDesign.DesignedComponent('ItemsList') as TCastleVerticalGroup;
end;

procedure TViewMarket.Stop;
begin
  inherited;
end;

procedure TViewMarket.AddItemRow(const AData: TMarketItemData);
var
  Row: TCastleHorizontalGroup;
  Slot: TCastleImageControl;
  NameLbl, TypeLbl, DescLbl, PriceLbl: TCastleLabel;
  Idx: Integer;
  Prefix: string;
begin
  Idx := ItemsList.ControlsCount;
  Prefix := Format('ItemRow%d_', [Idx]);

  Row := TCastleHorizontalGroup.Create(Self);
  Row.Height := 56;
  Row.Spacing := 6;
  Row.WidthFraction := 1.0;

  Slot := TCastleImageControl.Create(Self);
  Slot.Name := Prefix + 'Slot';
  Slot.Url := 'castle-data:/ui/slot_bg.png';
  Slot.Width := 56;
  Slot.Height := 56;
  Row.InsertFront(Slot);

  NameLbl := TCastleLabel.Create(Self);
  NameLbl.Name := Prefix + 'Name';
  NameLbl.Caption := AData.Name;
  NameLbl.AutoSize := False;
  NameLbl.Width := 160;
  NameLbl.Height := 56;
  NameLbl.VerticalAlignment := vpMiddle;
  NameLbl.Color := Vector4(0.85, 0.85, 0.85, 1.0);
  Row.InsertFront(NameLbl);

  TypeLbl := TCastleLabel.Create(Self);
  TypeLbl.Name := Prefix + 'Type';
  TypeLbl.Caption := AData.ItemType;
  TypeLbl.AutoSize := False;
  TypeLbl.Width := 80;
  TypeLbl.Height := 56;
  TypeLbl.VerticalAlignment := vpMiddle;
  TypeLbl.Color := Vector4(0.6, 0.6, 0.6, 1.0);
  Row.InsertFront(TypeLbl);

  DescLbl := TCastleLabel.Create(Self);
  DescLbl.Name := Prefix + 'Desc';
  DescLbl.Caption := AData.Description;
  DescLbl.AutoSize := False;
  DescLbl.Width := 200;
  DescLbl.Height := 56;
  DescLbl.VerticalAlignment := vpMiddle;
  DescLbl.Color := Vector4(0.7, 0.7, 0.7, 1.0);
  Row.InsertFront(DescLbl);

  PriceLbl := TCastleLabel.Create(Self);
  PriceLbl.Name := Prefix + 'Price';
  PriceLbl.Caption := Format('%dg', [AData.Price]);
  PriceLbl.AutoSize := False;
  PriceLbl.Width := 80;
  PriceLbl.Height := 56;
  PriceLbl.VerticalAlignment := vpMiddle;
  PriceLbl.Color := Vector4(1.0, 0.85, 0.3, 1.0);
  Row.InsertFront(PriceLbl);

  ItemsList.InsertFront(Row);
end;

procedure TViewMarket.ClearItems;
begin
  while ItemsList.ControlsCount > 0 do
    ItemsList.RemoveControl(ItemsList.Controls[0]);
end;

end.
