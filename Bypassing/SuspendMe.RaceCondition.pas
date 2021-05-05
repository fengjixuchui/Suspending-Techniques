unit SuspendMe.RaceCondition;

{
  The module includes the logic for bypassing suspension by winning the race
  condition.
}

interface

uses
  NtUtils;

// Create multiple threads that will try to win the race condition within the
// suspension mechanism
function RaceSuspension(
  UseStealthyMoode: Boolean
): TNtxStatus;

implementation

uses
  Ntapi.ntdef, Ntapi.ntpsapi, Ntapi.ntstatus, NtUtils.Threads, NtUtils.Sysutils;

var
  AllThreads: TArray<IHandle>;

// A function to execute on the helper threads
function ThreadMain(Context: Pointer): NTSTATUS; stdcall;
var
  CurrentIndex: NativeInt absolute Context;
  i: Integer;
begin
  // Resume all other threads in a loop

  while True do
    for i := 0 to High(AllThreads) do
      if i <> CurrentIndex then
      begin
        Result := NtResumeThread(AllThreads[i].Handle, nil);

        if not NT_SUCCESS(Result) then
          Exit;
      end;
end;

function RaceSuspension;
var
  Threads: TArray<IHandle>;
  Flags: TThreadCreateFlags;
  i, Count: Integer;
begin
  write('Specify the number of threads (2 or more): ');
  readln(Count);

  if Count >= 1 shl 24 then
  begin
    Result.Location := 'RaceSuspension';
    Result.Status := STATUS_TOO_MANY_THREADS;
    Exit;
  end
  else if Count < 2 then
  begin
    Result.Location := 'RaceSuspension';
    Result.Status := STATUS_INVALID_PARAMETER;
    Exit;
  end;

  Flags := THREAD_CREATE_FLAGS_CREATE_SUSPENDED;

  if UseStealthyMoode then
    Flags := Flags or THREAD_CREATE_FLAGS_SKIP_THREAD_ATTACH or
      THREAD_CREATE_FLAGS_HIDE_FROM_DEBUGGER;

  SetLength(Threads, Count + 1);

  // The first item is always the main thread. It does not run the bypass
  // logic, but it's there so that other threads can resume it
  Result := NtxOpenCurrentThread(Threads[0]);

  if not Result.IsSuccess then
    Exit;

  for i := 1 to High(Threads) do
  begin
    // Create other threads for circumventing the race condition
    Result := NtxCreateThread(Threads[i], NtCurrentProcess, ThreadMain,
      Pointer(i), Flags);

    if Result.IsSuccess then
      NtxSetNameThread(Threads[i].Handle, 'Resumer Thread #' + RtlxIntToStr(i))
    else
      Exit;
  end;

  // Here the user can adjust their priorities, etc.
  writeln;
  write('Ready? Press enter to start.');
  readln;

  AllThreads := Threads;
  Result := NtxResumeThread(Threads[High(Threads)].Handle);

  if not Result.IsSuccess then
    Exit;

  writeln('Try suspending any/all of them.');
end;

end.
