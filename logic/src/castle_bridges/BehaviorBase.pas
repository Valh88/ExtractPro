unit BehaviorBase;

{$mode objfpc}{$H+}

interface

uses
  Classes, CastleTransform, Interfaces;

type
  TBehaviorBase = class(TCastleBehavior)
  private
    FEntity: IGameEntity;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    property Entity: IGameEntity read FEntity write FEntity;

    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
  end;

implementation

{ TBehaviorBase }

constructor TBehaviorBase.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
end;

destructor TBehaviorBase.Destroy;
begin
  FEntity := nil;
  inherited;
end;

procedure TBehaviorBase.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
begin
  inherited Update(SecondsPassed, RemoveMe);
end;

end.
