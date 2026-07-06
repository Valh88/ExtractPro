unit JobQueue;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes, Variants, SyncObjs;

type
  TJobResult = reference to procedure(const Success: Boolean; const Data: Variant);
  TJobProc = reference to procedure(const OnResult: TJobResult);

  TJobTask = class
  public
    Job: TJobProc;
    OnResult: TJobResult;
    Started: Boolean;
    Done: Boolean;
    ResultSuccess: Boolean;
    ResultData: Variant;
  end;

  TJobCallback = class
  public
    OnResult: TJobResult;
    Success: Boolean;
    Data: Variant;
  end;

  TJobQueue = class
  private
    class var FQueue: TList;
    class var FCallbackQueue: TList;
    class var FLock: TCriticalSection;
    class var FWorker: TThread;
    class var FWorkerEvent: TEvent;
    class var FWorkerQueue: TList;
    class var FWorkerLock: TCriticalSection;
    class var FInitialized: Boolean;
    class procedure Initialize;
    class procedure WorkerProc;
    class procedure ProcessMainQueue;
  public
    class procedure Post(const Job: TJobProc;
      const OnResult: TJobResult = nil;
      Background: Boolean = False);
    class procedure Update;
  end;

implementation

class procedure TJobQueue.Initialize;
begin
  if not FInitialized then
  begin
    FQueue := TList.Create;
    FCallbackQueue := TList.Create;
    FLock := TCriticalSection.Create;
    FWorkerQueue := TList.Create;
    FWorkerLock := TCriticalSection.Create;
    FWorkerEvent := TEvent.Create(nil, False, False, '');
    FWorker := TThread.CreateAnonymousThread(@WorkerProc);
    FWorker.FreeOnTerminate := False;
    FWorker.Start;
    FInitialized := True;
  end;
end;

class procedure TJobQueue.WorkerProc;
var
  Task: TJobTask;
  cb: TJobCallback;
begin
  while True do
  begin
    FWorkerEvent.WaitFor(INFINITE);
    FWorkerEvent.ResetEvent;

    while True do
    begin
      Task := nil;
      FWorkerLock.Enter;
      try
        if FWorkerQueue.Count > 0 then
        begin
          Task := TJobTask(FWorkerQueue[0]);
          FWorkerQueue.Delete(0);
        end;
      finally
        FWorkerLock.Leave;
      end;

      if Task = nil then
        Break;

      try
        Task.Job(
          procedure (const Success: Boolean; const Data: Variant)
          begin
            cb := TJobCallback.Create;
            cb.OnResult := Task.OnResult;
            cb.Success := Success;
            cb.Data := Data;
            FLock.Enter;
            try
              FCallbackQueue.Add(cb);
            finally
              FLock.Leave;
            end;
            Task.Free;
          end
        );
      except
        cb := TJobCallback.Create;
        cb.OnResult := Task.OnResult;
        cb.Success := False;
        cb.Data := Null;
        FLock.Enter;
        try
          FCallbackQueue.Add(cb);
        finally
          FLock.Leave;
        end;
        Task.Free;
      end;
    end;
  end;
end;

class procedure TJobQueue.Post(const Job: TJobProc;
  const OnResult: TJobResult; Background: Boolean);
var
  Task: TJobTask;
begin
  Initialize;
  Task := TJobTask.Create;
  Task.Job := Job;
  Task.OnResult := OnResult;

  if Background then
  begin
    FWorkerLock.Enter;
    try
      FWorkerQueue.Add(Task);
    finally
      FWorkerLock.Leave;
    end;
    FWorkerEvent.SetEvent;
  end
  else
  begin
    FLock.Enter;
    try
      FQueue.Add(Task);
    finally
      FLock.Leave;
    end;
  end;
end;

class procedure TJobQueue.ProcessMainQueue;
var
  i: Integer;
  Task: TJobTask;
  cb: TJobCallback;
begin
  i := 0;
  while i < FQueue.Count do
  begin
    Task := TJobTask(FQueue[i]);
    if not Task.Started then
    begin
      Task.Started := True;
      Task.Job(
        procedure (const Success: Boolean; const Data: Variant)
        begin
          Task.ResultSuccess := Success;
          Task.ResultData := Data;
          Task.Done := True;
        end
      );
    end;

    if Task.Done then
    begin
      if Assigned(Task.OnResult) then
        Task.OnResult(Task.ResultSuccess, Task.ResultData);
      Task.Free;
      FQueue.Delete(i);
    end
    else
      Inc(i);
  end;

  for i := 0 to FCallbackQueue.Count - 1 do
  begin
    cb := TJobCallback(FCallbackQueue[i]);
    if Assigned(cb.OnResult) then
      cb.OnResult(cb.Success, cb.Data);
    cb.Free;
  end;
  FCallbackQueue.Clear;
end;

class procedure TJobQueue.Update;
begin
  if not FInitialized then Exit;

  FLock.Enter;
  try
    ProcessMainQueue;
  finally
    FLock.Leave;
  end;
end;

end.
