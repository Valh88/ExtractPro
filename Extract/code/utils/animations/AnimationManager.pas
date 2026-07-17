unit AnimationManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, UiAnimation;

type
  TAnimationList = specialize TObjectList<TBaseAnimation>;

  TAnimationManager = class
  private
    FList: TAnimationList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(AAnim: TBaseAnimation);
    procedure Remove(AAnim: TBaseAnimation);
    procedure Update(const SecondsPassed: Single);
    procedure Clear;
    function Count: Integer;
    function IsActive: Boolean;
  end;

implementation

{ TAnimationManager }

constructor TAnimationManager.Create;
begin
  inherited;
  FList := TAnimationList.Create(True);
end;

destructor TAnimationManager.Destroy;
begin
  FList.Free;
  inherited;
end;

procedure TAnimationManager.Add(AAnim: TBaseAnimation);
begin
  FList.Add(AAnim);
end;

procedure TAnimationManager.Remove(AAnim: TBaseAnimation);
begin
  FList.OwnsObjects := False;
  try
    FList.Remove(AAnim);
  finally
    FList.OwnsObjects := True;
  end;
end;

procedure TAnimationManager.Update(const SecondsPassed: Single);
var
  I, SavedCount: Integer;
begin
  SavedCount := FList.Count;
  I := 0;
  while I < SavedCount do
  begin
    FList[I].Update(SecondsPassed);
    Inc(I);
  end;
  for I := FList.Count - 1 downto 0 do
    if FList[I].IsComplete then
      FList.Delete(I);
end;

procedure TAnimationManager.Clear;
begin
  FList.Clear;
end;

function TAnimationManager.Count: Integer;
begin
  Result := FList.Count;
end;

function TAnimationManager.IsActive: Boolean;
begin
  Result := FList.Count > 0;
end;

end.
