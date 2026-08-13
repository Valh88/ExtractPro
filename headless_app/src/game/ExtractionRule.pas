unit ExtractionRule;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  help_types, GameWorld, ServerPartySystem, EntityTypes;

type
  { Контекст оценки правила экстракции. Собирается в TExtractPointSystem
    на момент проверки (вход в зону / каждый тик извлечения). }
  TExtractionContext = record
    PlayerId: TEntityId;
    ZoneIndex: Byte;
    World: TGameWorld;
    PartySystem: TServerPartySystem;
    ZonePlayers: array of TEntityId;  // кто сейчас в зоне ZoneIndex
  end;

  { Базовое правило экстракции. Наследники возвращают True — извлечение
    разрешено/продолжается, False — запрещено/отменяется. }
  TExtractionRule = class
  private
    FName: String;
  public
    constructor Create(const AName: String);
    function Evaluate(const Ctx: TExtractionContext): Boolean; virtual; abstract;
    property Name: String read FName;
  end;

implementation

constructor TExtractionRule.Create(const AName: String);
begin
  inherited Create;
  FName := AName;
end;

end.
