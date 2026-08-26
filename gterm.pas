unit gterm;

{$mode objfpc}{$H+}{$R+}

interface

procedure TermInit;
procedure TermDone;
procedure TermRun;
  
implementation

uses
  SysUtils, Math, Video, Keyboard,
  dcommon, doption, gdoc, gscreen
{$IFDEF DEBUG}, debug{$ENDIF};

var
  ExitProgram : boolean;
  TopLine : SizeInt; // Display line at the top of the screen
  Cursor : tCursor;  // Document Cursor
  CursorX,
  CursorY : integer;  // Screen Cursor
  Scr : tScreen;
  
procedure TermInit;
begin
  InitKeyboard;
  InitVideo;
  
  Scr := tScreen.Create (ScreenWidth, ScreenHeight);  
  Cursor.Paragraph := 1;
  Cursor.Position := 1;
  CursorX := 1;
  CursorY := 1;
  TopLine := 0;
end;

procedure TermDone;
begin
  Scr.Free;
  DoneVideo;
  DoneKeyboard;
end;

function MaxX : integer;
begin
  Result := ScreenWidth - 1;
end;

function MaxY : integer;
begin
  Result := ScreenHeight - 1;
end;

function BottomLine : integer;
begin
  Result := TopLine + (MaxY - 1);
end;

// Display handling routines
{$I gterm-vid.inc}

// Keyboard handling routines
{$I gterm-key.inc}

procedure TermRun;
begin
  Scr.Repaginate (Document); 
  repeat
    ExitProgram := FALSE;
    DrawScreen;
    HandleKeyboard;
  until ExitProgram;
  Clrscr;
  UpdateScreen (FALSE)
end;

end.
