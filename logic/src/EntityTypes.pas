unit EntityTypes;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, Classes, help_types, Interfaces;

type
  { Инвентарь (макс. 20 слотов) }
  TInventory = record
  private
    FItems: TItemArray;
  public
    procedure Init;
    procedure Free;
    function AddItem(const Item: TItemData): Boolean;
    procedure RemoveItem(Index: Integer);
    procedure Clear;
    function Count: Integer;
    function GetItem(Index: Integer): TItemData;
    procedure SetItem(Index: Integer; const Item: TItemData);
  end;

  TEnemyData = record
    Id: TEntityId;
    Stats: TEntityStats;
    AIState: TAIState;
    DetectionRange: Single;
    AttackRange: Single;
    Damage: Single;
    LootTable: TItemArray;
    SpawnPosition: TVector2;
    Visual: IGameEntity;
  end;

  TEnemyArray = array of TEnemyData;

  TPlayerState = (psInLobby, psInGame);

  TPlayerStatus = (psInRaid, psExtracted, psDead);

  TPlayerData = record
    Id: TEntityId;
    Stats: TEntityStats;
    Inventory: TInventory;
    Status: TPlayerStatus;
    IsExtracting: Boolean;
    ExtractionProgress: Single;
    Kills: Integer;
    Damage: Single;
    AttackRange: Single;
    Visual: IGameEntity;
    procedure Heal(Amount: Single);
    procedure Init;
    procedure Free;
  end;

  TBulletData = record
    Id: TEntityId;
    OwnerId: TEntityId;
    Visual: IGameEntity;
  end;

  TBulletArray = array of TBulletData;

implementation

{ TInventory }

procedure TInventory.Init;
begin
  FItems := nil;
end;

procedure TInventory.Free;
begin
  FItems := nil;
end;

function TInventory.AddItem(const Item: TItemData): Boolean;
begin
  if Length(FItems) >= 20 then
    Exit(False);
  SetLength(FItems, Length(FItems) + 1);
  FItems[High(FItems)] := Item;
  Result := True;
end;

procedure TInventory.RemoveItem(Index: Integer);
var
  i: Integer;
begin
  if (Index < 0) or (Index >= Length(FItems)) then
    Exit;
  for i := Index to High(FItems) - 1 do
    FItems[i] := FItems[i + 1];
  SetLength(FItems, Length(FItems) - 1);
end;

procedure TInventory.Clear;
begin
  FItems := nil;
end;

function TInventory.Count: Integer;
begin
  Result := Length(FItems);
end;

function TInventory.GetItem(Index: Integer): TItemData;
begin
  Result := FItems[Index];
end;

procedure TInventory.SetItem(Index: Integer; const Item: TItemData);
begin
  FItems[Index] := Item;
end;

{ TPlayerData }

procedure TPlayerData.Heal(Amount: Single);
begin
  Stats.Health := Stats.Health + Amount;
  if Stats.Health > Stats.MaxHealth then
    Stats.Health := Stats.MaxHealth;
end;

procedure TPlayerData.Init;
begin
  Inventory.Init;
end;

procedure TPlayerData.Free;
begin
  Inventory.Free;
end;

end.
