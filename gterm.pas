unit gterm;

{$mode objfpc}{$H+}{$R+}

interface

procedure TermInit;
procedure TermDone;
procedure TermRun;
  
implementation

uses
  SysUtils, Math, Video, Keyboard,
  dcommon, doption, gdoc, gscreen, gtheme
{$IFDEF DEBUG}, debug{$ENDIF};

var
  ExitProgram : boolean;
  TopLine : SizeInt;   // Display line at the top of the screen
  BlockStart,
  BlockEnd,            // Block extents
  Cursor : tCursor;    // Document Cursor
  CursorX,
  CursorY : integer;   // Screen Cursor
  Scr : tScreen;
  Overwrite,
  ReplaceOnFind  : boolean;
  MessageString : string = 'Welcome to FicWrite';
  SearchTerm : string = '';
  ReplaceTerm : string = '';
  Clipboard : array of char;

// Forward Declarations
{$I gterm.h}

procedure TermInit;
begin
  InitVideo;
  if (ScreenWidth < MinScreenWidth) then begin
    DoneVideo;
    Writeln ('Minimum width is ', MinScreenWidth, ' characters.');
    Halt(1);
  end;
  InitKeyboard;
  SetTheme (ThemeBlueWhite);
  
  Scr := tScreen.Create (ScreenWidth, ScreenHeight);  
  Cursor.Paragraph := 1;
  Cursor.Position := 1;
  BlockClear;
  CursorX := 1;
  CursorY := 1;
  TopLine := 0;
  Overwrite := FALSE;
  ReplaceOnFind := FALSE;
  SearchTerm := '';
  ReplaceTerm := '';
  SetCursorType (crUnderline);
end;

procedure TermDone;
begin
  Scr.Free;
  SetLength (Clipboard,0);
  DoneKeyboard;
  DoneVideo;
end;

// Display handling routines
{$I gterm-vid.inc}

// File management routines
{$I gterm-file.inc}

// Keyboard handling routines
{$I gterm-key.inc}

// Block handling routines
{$I gterm-block.inc}

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
