unit debug;

{$H+}

interface

procedure StartDebug (aFilename : string);
procedure DebugLog (s : string);
procedure StopDebug;

implementation

var
  t : text;

procedure StartDebug (aFilename : string);
begin
  System.assign (t, aFilename);
  System.rewrite (t);
end;

procedure DebugLog (s : string);
begin
  writeln (t, s);
end;

procedure StopDebug;
begin
  System.close (t);
end;

end.
