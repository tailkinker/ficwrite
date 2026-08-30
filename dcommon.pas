unit dcommon;

{$mode objfpc}{$H+}{$R+}

// Contains the things needed by pretty much every other unit.

interface

uses
  video;
  
type
  TStringArray = array of string;
  
  TCursor = record
    Paragraph: SizeInt;
    Position: SizeInt;
  end;

  tPoint = record
    X,
    Y : integer;
  end;
  
  tRect = record
    A,
    B : tPoint;
  end;

  tDirEntry = record
    Filename : string;
    Directory : boolean;
  end;

  tDirArray = array of tDirEntry;
  
  
const
  PARAGRAPH_MARKER = #$81;
  MinScreenWidth = 70;
{$IFDEF MSWINDOWS}
  AltKBText = 'Alt+';
{$ELSE}
  AltKBText = 'Esc+';
{$ENDIF}

  yncYes = 0;
  yncNo = 1;
  yncCancel = 2;
  
implementation

end.
