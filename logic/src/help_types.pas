unit help_types;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, Classes;

type
  { 2D вектор }
  TVector2 = record
    X, Y: Single;
  end;

  { 3D вектор }
  TVector3 = record
    X, Y, Z: Single;
  end;

  { Цвет }
  TColor4 = record
    R, G, B, A: Single;
  end;

  { Прямоугольник }
  TRectangle = record
    Left, Bottom, Width, Height: Single;
  end;

  { Уникальный ID сущности }
  TEntityId = type UInt32;

  { Тип урона }
  TDamageType = (dtPhysical, dtMagical, dtTrue);

  TDamageInfo = record
    Amount: Single;
    DamageType: TDamageType;
    SourceId: TEntityId;
  end;

  { Базовые характеристики живой сущности }
  TEntityStats = record
    Health: Single;
    MaxHealth: Single;
    Speed: Single;
    Armor: Single;
    procedure TakeDamage(const Damage: TDamageInfo);
    function IsAlive: Boolean;
    function HealthPercent: Single;
  end;

  { Типы предметов }
  TItemType = (itWeapon, itArmor, itConsumable, itKey, itValuables);
  TItemRarity = (irCommon, irUncommon, irRare, irExotic);

  TItemData = record
    ItemType: TItemType;
    Rarity: TItemRarity;
    Name: String;
    Weight: Single;
    Value: Single;
    Damage: Single;
    HealAmount: Single;
    StackCount: Integer;
    MaxStack: Integer;
  end;

  TItemArray = array of TItemData;

  TAIState = (asIdle, asPatrol, asChase, asAttack, asDead);

  TRoomType = (rtSpawn, rtNormal, rtExtraction, rtBoss);

implementation

{ TEntityStats }

procedure TEntityStats.TakeDamage(const Damage: TDamageInfo);
var
  EffectiveDamage: Single;
begin
  EffectiveDamage := Damage.Amount * (1 - Armor / (Armor + 100));
  if EffectiveDamage < 1 then
    EffectiveDamage := 1;
  Health := Health - EffectiveDamage;
  if Health < 0 then
    Health := 0;
end;

function TEntityStats.IsAlive: Boolean;
begin
  Result := Health > 0;
end;

function TEntityStats.HealthPercent: Single;
begin
  Result := Health / MaxHealth;
end;

end.
