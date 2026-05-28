{
  Базовый класс состояния для машины состояний.

  Описание:
    TState<T> - абстрактный базовый класс для всех состояний.
    Наследуйтесь от него и переопределяйте методы Enter, Update, Exit.

  Использование:
    type
      TGameState = (gsMenu, gsPlaying, gsPaused);

      TMenuState = class(specialize TState<TGameState>)
      public
        procedure Enter(FromState: TGameState); override;
        procedure Update(DeltaTime: single); override;
        procedure Exit(ToState: TGameState); override;
      end;

    procedure TMenuState.Enter(FromState: TGameState);
    begin
      // Инициализация при входе в состояние
      ShowMainMenu;
    end;

    procedure TMenuState.Update(DeltaTime: single);
    begin
      // Логика обновления каждый кадр
      if StartButtonPressed then
        ChangeState(gsPlaying);
    end;

    procedure TMenuState.Exit(ToState: TGameState);
    begin
      // Очистка при выходе из состояния
      HideMainMenu;
    end;

  Методы:
    - Enter(FromState) - вызывается при входе в состояние
    - Update(DeltaTime) - вызывается каждый кадр
    - Exit(ToState) - вызывается при выходе из состояния
    - ChangeState(NewState) - вспомогательный метод для смены состояния
}
unit State;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  { Forward declaration для TStateMachine }
  generic TStateMachineBase<T> = class;

  {
    Базовый класс для всех состояний.

    @param T - Тип идентификатора состояния (обычно enum)

    Переопределите методы Enter, Update, Exit в наследниках
    для реализации логики конкретного состояния.

    Пример:
      TPlayingState = class(specialize TState<TGameState>)
        procedure Enter(FromState: TGameState); override;
        procedure Update(DeltaTime: single); override;
        procedure Exit(ToState: TGameState); override;
      end;
  }
  generic TState<T> = class
  private
    FStateMachine: specialize TStateMachineBase<T>;
  protected
    {
      Вызывает смену состояния через машину состояний.
      Удобный метод для использования внутри состояния.
      @param NewState - Новое состояние
    }
    procedure ChangeState(NewState: T);
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure Enter(FromState: T); virtual;
    procedure Update(DeltaTime: single); virtual;
    procedure Exit(ToState: T); virtual;
    property StateMachine: specialize TStateMachineBase<T>
      read FStateMachine write FStateMachine;
  end;

  generic TStateMachineBase<T> = class
  public
    procedure ChangeState(NewState: T); virtual; abstract;
  end;

implementation

{ TState }

constructor TState.Create;
begin
  inherited Create;
  FStateMachine := nil;
end;

destructor TState.Destroy;
begin
  inherited Destroy;
end;

procedure TState.Enter(FromState: T);
begin
  // Переопределите в наследнике
end;

procedure TState.Update(DeltaTime: single);
begin
  // Переопределите в наследнике
end;

procedure TState.Exit(ToState: T);
begin
  // Переопределите в наследнике
end;

procedure TState.ChangeState(NewState: T);
begin
  if FStateMachine <> nil then
    FStateMachine.ChangeState(NewState);
end;

end.
