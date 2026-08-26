unit doption;

{$mode objfpc}{$H+}{$R+}

interface

uses
  Video;

type
  TOptions = record
    UpperFlags: set of 'A'..'Z';
    LowerFlags: set of 'a'..'z';
    FileName: string;
  end;

var
  Options: TOptions;

procedure ParseCommandLine;

implementation

procedure ParseCommandLine;
var
  I, J: Integer;
  Param: string;
  FoundFileName: Boolean;
begin
  Options.UpperFlags := [];
  Options.LowerFlags := [];
  Options.FileName := '';

  FoundFileName := False;
  I := 1;

  while (I <= ParamCount) and not FoundFileName do
  begin
    Param := ParamStr(I);

    if (Length(Param) > 0) and (Param[1] = '-') then
    begin
      { Every character after '-' is an option flag. }
      for J := 2 to Length(Param) do
      begin
        if Param[J] in ['A'..'Z'] then
          Include(Options.UpperFlags, Param[J])
        else if Param[J] in ['a'..'z'] then
          Include(Options.LowerFlags, Param[J]);
      end;
    end
    else
    begin
      { First naked parameter is the filename. }
      Options.FileName := Param;
      FoundFileName := True;
    end;

    Inc(I);
  end;
end;

end.
