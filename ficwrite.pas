{
FicWrite 0.1b
Copyright © 2026 Timothy Groves

FicWrite is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published
by the Free Software Foundation, either version 3 of the License,
or (at your option) any later version.

FicWrite is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with FicWrite. If not, see <https://www.gnu.org/licenses/>.
}
program ficwrite;

// Compile with
// fpc -dDEBUG ficwrite
// for debugging

{$mode objfpc}{$H+}{$R+}

uses
  SysUtils, dcommon, doption, gdoc, gterm, gtheme
{$IFDEF DEBUG}, debug{$ENDIF};

begin
  Theme := themeWordPerfect;
  LoadRCFile;

  ParseCommandLine;
  if ('p' in Options.LowerFlags) then
    TerminalMode := 0
  else if ('v' in Options.LowerFlags) then
    TerminalMode := 1;
  if ('t' in Options.LowerFlags) then
    Theme := themeTerminal
  else if ('y' in Options.LowerFlags) then
    Theme := themeTypewriter
  else if ('c' in Options.LowerFlags) then
    Theme := themeCyberdeck
  else if ('w' in Options.LowerFlags) then
    Theme := themeWordPerfect;

  {$IFDEF DEBUG}
  StartDebug('/dev/pts/5');
//  Options.Filename := 'loremipsum.txt';
  {$ENDIF}

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
  
  SaveRCFile;  
end.
