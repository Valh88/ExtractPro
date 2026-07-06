unit DbItems;

{$mode objfpc}{$H+}

interface

uses
  mormot.core.base,
  mormot.orm.core,
  DbAccounts;

type
  TOrmItemDefinition = class(TOrm)
  private
    fItemType: Int64;
    fRarity: Int64;
    fName: RawUtf8;
    fWeight: Double;
    fValue: Double;
    fBaseDamage: Double;
    fHealAmount: Double;
    fMaxStack: Integer;
  published
    property ItemType: Int64 read fItemType write fItemType;
    property Rarity: Int64 read fRarity write fRarity;
    property Name: RawUtf8 read fName write fName;
    property Weight: Double read fWeight write fWeight;
    property Value: Double read fValue write fValue;
    property BaseDamage: Double read fBaseDamage write fBaseDamage;
    property HealAmount: Double read fHealAmount write fHealAmount;
    property MaxStack: Integer read fMaxStack write fMaxStack;
  end;

  TOrmPlayerItem = class(TOrm)
  private
    fAccount: TOrmGameAccount;
    fItemDef: TOrmItemDefinition;
    fStackCount: Integer;
    fSlotIndex: Integer;
  published
    property Account: TOrmGameAccount read fAccount write fAccount;
    property ItemDef: TOrmItemDefinition read fItemDef write fItemDef;
    property StackCount: Integer read fStackCount write fStackCount;
    property SlotIndex: Integer read fSlotIndex write fSlotIndex;
  end;

implementation

end.
