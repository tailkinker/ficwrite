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
  
const
  version = '0.2b';

procedure ParseCommandLine;
procedure LoadRCFile;
procedure SaveRCFile;
  
implementation
  
uses
  sysutils, gtheme, dcommon;

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

function ConfigDir : string;
begin
  Result := GetUserDir + '.config' + DirectorySeparator + 'ficwrite';
end;

function OpenConfig(var T: TextFile): Boolean;
begin
  Assign(T, ConfigDir + DirectorySeparator + 'rc.ficwrite');
  {$I-}
  Reset(T);
  {$I+}
  Result := IOResult = 0;
end;

function HandleKey (const k, v: string) : boolean;
begin
  Result := TRUE;
  if (k = 'Terminal') then begin
    if (v = 'VT100') then
      TerminalMode := 1
    else if (v = 'PC') then
      TerminalMode := 0
  end else if (k = 'Theme') then begin
    if (v = 'Terminal') then
      Theme := themeTerminal
    else if (v = 'WordPerfect') then
      Theme := themeWordPerfect
    else if (v = 'Typewriter') then
      Theme := themeTypewriter
    else if (v = 'Cyberdeck') then
      Theme := themeCyberdeck;
  end else
    Result := FALSE;
end;   

procedure WriteKey (var T: text; const k, v : string);
begin
  writeln (t, k, ' = ', v);
end;

procedure WriteKeys (var T : text);
begin
  case TerminalMode of
    0 : WriteKey (T, 'Terminal', 'PC');
    1 : WriteKey (T, 'Terminal', 'VT100');
  end;
  case Theme of
    themeTerminal : WriteKey (T, 'Theme', 'Terminal');
    themeWordPerfect : WriteKey (T, 'Theme', 'WordPerfect');
    themeTypewriter : WriteKey (T, 'Theme', 'Typewriter');
    themeCyberdeck : WriteKey (T, 'Theme', 'Cyberdeck');
  end;
end;    

function VerifyConfigDirectory: Boolean;
begin
  Result := DirectoryExists(ConfigDir);
  if not Result then
    Result := ForceDirectories(ConfigDir) and DirectoryExists(ConfigDir);
end;

function CreateConfig(var T: TextFile): Boolean;
begin
  Assign(T, ConfigDir + DirectorySeparator + 'rc.ficwrite');
  {$I-}
  Rewrite(T);
  {$I+}
  Result := IOResult = 0;
end;
  
procedure LoadRCFile;
var
  T : Text;
  k,
  v,
  s : string;
  i : longint;
  Done : boolean;   
begin
  if (VerifyConfigDirectory) then begin
    if OpenConfig (T) then begin
      Done := false;
      while (not Done) and (not EoF(t)) do begin
        // Read Keyline
        readln (t, s);
        if (length (s) > 0) then
          s := Trim (s);
        if (s = '') then
          Continue;
        // Find the = sign
        i := Pos('=', s);

        // Split Keyline
        if (i = 0) then begin
          k := s;
          v := ''
        end else begin
          k := Trim (copy (s, 1, i - 1));
          v := Trim (copy (s, i + 1, length (s) - i))
        end;

        HandleKey (k, v);
      end;
      Close (T);
    end;  
  end else begin
    writeln ('Cannot access ' + ConfigDir);
    Halt (1);
  end;  
end;

procedure SaveRCFile;
var
  T : text;
begin
  if (VerifyConfigDirectory) then begin
    if CreateConfig (T) then begin
      WriteKeys (T);
      Close (T);
    end else begin
      writeln ('Cannot open ' + ConfigDir + DirectorySeparator + 'rc.ficwrite');
      Halt (1);
    end
  end else begin
    writeln ('Cannot access ' + ConfigDir);
    Halt (1);
  end;
end;

end.
