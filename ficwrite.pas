program ficwrite;

// Compile with
// fpc -dDEBUG ficwrite
// for debugging

{$mode objfpc}{$H+}{$R+}

uses
  SysUtils, doption, gdoc, gterm
{$IFDEF DEBUG}, debug{$ENDIF};

begin
  {$IFDEF DEBUG}
  StartDebug('/dev/pts/0');
  {$ENDIF}
  ParseCommandLine;

  Options.Filename := 'loremipsum.txt';
  Document := TDocument.Create;
  try
    if Options.FileName <> '' then begin
      Document.LoadFromFile(Options.FileName);
    end;

    TermInit;
    try
      TermRun;
    finally
      TermDone;
    end;
  finally
    Document.Free;
    {$IFDEF DEBUG}
    StopDebug;
    {$ENDIF}
  end;
end.
